//
//  AlarmCardView.swift
//  RiseUp
//
//  LAYER: View (one row of the Alarm List)
//  WHAT:  A glowing card: big time, label + repeat days, mission icons, on/off switch.
//  DATA:  READS an AlarmRow (a value snapshot). It never sees the database object and
//         never saves anything; changes go out through closures.
//
//  CONNECTIONS:
//    ← USED BY:  AlarmListView, once per row in `ForEach(viewModel.rows)`
//    ← INPUT:    `row` built by AlarmListViewModel.rows (see AlarmRow.swift for why a snapshot)
//    → onToggle: AlarmListView forwards it → AlarmListViewModel.setEnabled(_:alarmID:)
//    → onTap:    AlarmListView forwards it → AlarmListViewModel.alarmTapped(alarmID:) → coordinator → editor
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

    var body: some View {
        GlowCard(isGlowing: row.isEnabled) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Left side: tapping it opens the editor.
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        BigClockText(hour: row.hour, minute: row.minute, size: 46, isActive: row.isEnabled)

                        Text(row.subtitle)
                            .font(.riseCaption)
                            .foregroundStyle(row.isEnabled ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                            .lineLimit(1)

                        if !row.missionTypes.isEmpty {
                            missionIcons
                        }
                    }
                    // LEARN: `.contentShape(Rectangle())` makes the WHOLE area tappable,
                    // including the empty space between texts, not just the visible pixels.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the alarm editor")

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

    /// Small pills showing each mission's icon.
    private var missionIcons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // LEARN: ForEach needs a unique id per item. A mission type can appear twice
            // (e.g. two Math missions), so we use its position (`offset`) as the id instead.
            ForEach(Array(row.missionTypes.enumerated()), id: \.offset) { _, type in
                Image(systemName: type.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(row.isEnabled ? Theme.Colors.neonPink : Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Colors.surfaceRaised, in: .capsule)
                    .accessibilityLabel("\(type.title) mission")
            }
        }
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
