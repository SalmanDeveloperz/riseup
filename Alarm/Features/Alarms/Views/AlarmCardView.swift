//
//  AlarmCardView.swift
//  RiseUp
//
//  LAYER: View (one row of the Alarm List)
//  WHAT:  A glowing card: big time, label + repeat days, mission chips (or "+ Add mission"), on/off switch.
//  DATA:  READS an AlarmRow (a value snapshot). It never sees the database object and
//         never saves anything; changes go out through closures.
//
//  CONNECTIONS:
//    ← USED BY:  AlarmListView, once per row in `ForEach(viewModel.rows)`
//    ← INPUT:    `row` built by AlarmListViewModel.rows (see AlarmRow.swift for why a snapshot)
//    → onToggle: AlarmListView forwards it → AlarmListViewModel.setEnabled(_:alarmID:)
//    → onTap:    AlarmListView forwards it → AlarmListViewModel.alarmTapped(alarmID:) → coordinator → editor
//    → onAddMission: AlarmListView forwards it → AlarmListViewModel.addMission(toAlarm:) → Mission Picker → saved (#38)
//
//  LEARN: Why closures instead of giving the card the ViewModel?
//  The card stays reusable and "dumb": it says "the user flipped the switch" and
//  doesn't care what happens next. We could reuse this card on a widget or in
//  onboarding without changing it.
//

import SwiftUI

struct AlarmCardView: View {
    let row: AlarmRow
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    /// "+ Add mission" (#38). nil = no pill (e.g. a preview of a read-only card).
    var onAddMission: (() -> Void)? = nil

    var body: some View {
        GlowCard(isGlowing: row.isEnabled) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Left side: tapping it opens the editor. Below it, its own button: "+ Add mission".
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Button(action: onTap) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            BigClockText(hour: row.hour, minute: row.minute, size: 46, isActive: row.isEnabled)

                            Text(row.subtitle)
                                .font(.riseCaption)
                                .foregroundStyle(row.isEnabled ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                                .lineLimit(1)

                            if !row.missionTypes.isEmpty {
                                missionChips
                            }
                        }
                        // LEARN: `.contentShape(Rectangle())` makes the WHOLE area tappable,
                        // including the empty space between texts, not just the visible pixels.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the alarm editor")
                    // WHY outside the editor Button: the pill is its OWN button; inside, both would fire.
                    if row.missionTypes.isEmpty, let onAddMission { addMissionPill(onAddMission) }
                }

                // Right side: the switch. It's kept OUTSIDE the Button so both can be tapped separately.
                // The label is hidden visually but VoiceOver still reads it.
                Toggle(row.subtitle, isOn: isOnBinding)
                    .toggleStyle(.neon)
                    .labelsHidden()
                    .fixedSize()
            }
        }
    }

    // MARK: - Pieces

    /// "⚡︎ Math · Steps": the missions, by name (icons only when there are three).
    private var missionChips: some View {
        let showsNames = row.missionTypes.count <= 2
        return HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "bolt.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(row.isEnabled ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.textTertiary))
            // LEARN: ForEach needs a unique id per item. A mission type can appear twice
            // (e.g. two Math missions), so we use its position (`offset`) as the id instead.
            ForEach(Array(row.missionTypes.enumerated()), id: \.offset) { _, type in
                // WHY an HStack (not a Label): a Label puts a wide gap between icon and text (found in the
                // Simulator); chips read better tight.
                HStack(spacing: 3) {
                    Image(systemName: type.systemImage)
                    if showsNames { Text(type.shortTitle) }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(row.isEnabled ? Theme.Colors.accent : Theme.Colors.textTertiary)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(Theme.Colors.surfaceRaised, in: .capsule)
                .accessibilityLabel("\(type.title) mission")
            }
        }
    }

    /// "+ Add mission": one tap → Mission Picker → saved, without opening the editor. (#38)
    private func addMissionPill(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                Text("Add mission")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(row.isEnabled ? Theme.Colors.accent : Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs + 1)
            .overlay {
                Capsule().strokeBorder(row.isEnabled ? Theme.Colors.accent : Theme.Colors.hairline,
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .contentShape(.capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint("Choose a mission that must be done to stop this alarm")
    }

    /// Connects the switch to the row.
    ///
    /// LEARN: a `Binding` is a two-way connection: `get` tells the switch what to show,
    /// `set` is called when the user flips it. We READ from the snapshot, but WRITE
    /// through `onToggle`, so the ViewModel decides (it may ask for permission or roll back
    /// if iOS refuses). The ViewModel's change then produces a NEW row with the new value.
    private var isOnBinding: Binding<Bool> {
        Binding(
            get: { row.isEnabled },
            set: { newValue in onToggle(newValue) }
        )
    }
}

#Preview {
    // LEARN: with snapshots, previews don't need a database at all; just plain values.
    @Previewable @State var isOn = true
    VStack(spacing: Theme.Spacing.md) {
        AlarmCardView(
            row: AlarmRow(id: UUID(), hour: 6, minute: 30, isEnabled: isOn,
                          subtitle: "Gym · Weekdays", missionTypes: [.math, .shake]),
            onToggle: { isOn = $0 },
            onTap: {}
        )
        AlarmCardView(
            row: AlarmRow(id: UUID(), hour: 9, minute: 0, isEnabled: false,
                          subtitle: "Weekends", missionTypes: []),
            onToggle: { _ in },
            onTap: {}
        )
    }
    .padding()
    .appBackground()
}
