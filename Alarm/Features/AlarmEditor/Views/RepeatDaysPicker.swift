//
//  RepeatDaysPicker.swift
//  RiseUp
//
//  LAYER: View (part of the Alarm Editor)
//  WHAT:  Seven round day chips (M T W T F S S) plus quick presets
//         ("Weekdays", "Weekends", "Every day", "Once").
//  DATA:  none stored. It edits a `Set<Weekday>` (and, in the editor, the "Once + days" flag) through Bindings.
//
//  "ONCE + DAYS" (#36): with no days, "Once" = a one-time alarm (as always). With days selected, tapping
//  "Once" ADDS one extra ring at the next time (today/tomorrow) on top of them: Once + Wed = today 12:00
//  and then every Wednesday 12:00. Tap it again to remove the extra ring.
//
//  CONNECTIONS:
//    ← USED BY:    AlarmEditorView → `RepeatDaysPicker(selection: $viewModel.draft.repeatDays, …)`
//    → WRITES:     the Binding, i.e. AlarmEditorViewModel.draft.repeatDays
//    → onPreset:   AlarmEditorViewModel.applyRepeatPreset(_:)
//
//  LEARN: `@Binding` = "a value that belongs to someone else, which I'm allowed to
//  change". The picker doesn't own the selected days; the editor's draft does.
//  Tapping a chip changes the draft directly, and the whole editor sees it.
//

import SwiftUI

struct RepeatDaysPicker: View {
    @Binding var selection: Set<Weekday>
    /// "Once + days" (#36). `nil` (onboarding) = the classic behaviour: "Once" just clears the days.
    var alsoOnce: Binding<Bool>? = nil
    var onPreset: (Set<Weekday>) -> Void

    /// LEARN: `@ScaledMetric` grows a number with the user's text size (Settings → Display →
    /// Text Size), so the day letters never overflow their circles at big sizes.
    @ScaledMetric(relativeTo: .headline) private var chipSize: CGFloat = 40

    /// Preset buttons: title + the days it selects.
    private let presets: [(title: String, days: Set<Weekday>)] = [
        ("Once", []),
        ("Weekdays", [.monday, .tuesday, .wednesday, .thursday, .friday]),
        ("Weekends", [.saturday, .sunday]),
        ("Every day", Set(Weekday.allCases))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // The 7 chips, in the user's calendar order (Mon-first in Pakistan).
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Weekday.orderedForCurrentLocale) { day in
                    dayChip(day)
                }
            }

            // Presets: horizontally scrollable so they never squeeze on small phones.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(presets, id: \.title) { preset in
                        presetChip(preset.title, days: preset.days)
                    }
                }
            }
        }
        // LEARN: one haptic tick whenever the selection changes, whoever changed it.
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: - Pieces

    private func dayChip(_ day: Weekday) -> some View {
        let isOn = selection.contains(day)
        return Button {
            // LEARN: a Set can't hold duplicates. Insert/remove toggles membership.
            if isOn { selection.remove(day) } else { selection.insert(day) }
            // No days left = a plain one-time alarm; the "Once + days" extra no longer means anything.
            if selection.isEmpty { alsoOnce?.wrappedValue = false }
        } label: {
            Text(day.veryShortName)
                .font(.riseHeadline)
                .foregroundStyle(isOn ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                .frame(width: chipSize, height: chipSize)
                .minimumScaleFactor(0.7)
                .background {
                    Circle().fill(isOn ? AnyShapeStyle(Theme.Gradients.brand)
                                       : AnyShapeStyle(Theme.Colors.surfaceRaised))
                }
                .shadow(color: isOn ? Theme.Colors.accent.opacity(0.45) : .clear, radius: 8)
                // LEARN: each 40-pt circle sits in a slot that stretches (`maxWidth: .infinity`),
                // so the 7 slots share the row equally and the circles spread evenly on any iPhone.
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isOn)
        .accessibilityLabel(day.shortName)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func presetChip(_ title: String, days: Set<Weekday>) -> some View {
        let isOncePreset = days.isEmpty
        // "Once" is lit for a one-time alarm AND for "Once + days"; other presets when their days match.
        let isActive = isOncePreset ? (selection.isEmpty || (alsoOnce?.wrappedValue ?? false)) : selection == days
        return Button(title) {
            if isOncePreset, let alsoOnce, !selection.isEmpty {
                alsoOnce.wrappedValue.toggle()            // Once + days: add / remove the extra ring
            } else {
                onPreset(days)                            // → ViewModel (classic presets)
            }
        }
            .font(.riseCaption)
            .foregroundStyle(isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isActive ? Theme.Colors.accent.opacity(0.22) : Theme.Colors.surfaceRaised, in: .capsule)
            .overlay { Capsule().strokeBorder(isActive ? Theme.Colors.accent : .clear) }
            .frame(minHeight: 44)                 // finger-sized tap area; the capsule still looks small
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .accessibilityHint(isOncePreset && alsoOnce != nil && !selection.isEmpty
                               ? "Also rings one extra time, at the next alarm time" : "")
    }
}

#Preview {
    @Previewable @State var days: Set<Weekday> = [.monday, .wednesday, .friday]
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        RepeatDaysPicker(selection: $days, onPreset: { days = $0 })
        Text(Weekday.summary(for: days)).foregroundStyle(Theme.Colors.textSecondary)
    }
    .padding()
    .appBackground()
}
