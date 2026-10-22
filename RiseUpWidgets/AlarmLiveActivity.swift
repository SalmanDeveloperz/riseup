//
//  AlarmLiveActivity.swift
//  RiseUpWidgets (widget extension)
//
//  LAYER: Widget extension (Screen #30: lock screen / Dynamic Island alarm UI)
//  WHAT:  How a RiseUp alarm looks OUTSIDE the app:
//           • lock screen banner (ringing, snoozing, paused)
//           • Dynamic Island (compact, minimal and expanded)
//  DATA:  reads AlarmAttributes<RiseUpAlarmMetadata> (what we set when scheduling) and
//         AlarmPresentationState (what iOS says is happening now). No SwiftData.
//
//  CONNECTIONS:
//    ← LISTED IN:  RiseUpWidgetsBundle
//    ← DATA FROM:  AlarmKitScheduler.makeAttributes (title, tint, metadata) → stored by iOS
//                  iOS itself (the live state: alerting / counting down / paused)
//    → USES:       Shared/RiseUpAlarmMetadata, Shared/DesignSystem/Theme
//
//  HOW IT GETS HERE:
//    AlarmKitScheduler.schedule(...) → AlarmManager.shared.schedule(configuration)
//      → iOS keeps the attributes → when the alarm rings / snoozes, iOS starts a
//        Live Activity → iOS launches THIS extension → `ActivityConfiguration` draws it.
//
//  WHY no buttons here: while the alarm RINGS, iOS draws its own Stop / "Start Mission"
//  buttons from `AlarmPresentation.Alert`. This file only adds our look around it.
//

import AlarmKit
import SwiftUI
import WidgetKit

// MARK: - The Live Activity

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // LEARN: `ActivityConfiguration(for:)` says "I know how to draw Live Activities
        // whose attributes are of THIS type". The type must match the one the app
        // schedules with (`AlarmAttributes<RiseUpAlarmMetadata>`) or iOS won't use it.
        ActivityConfiguration(for: AlarmAttributes<RiseUpAlarmMetadata>.self) { context in
            // 1. Lock screen / notification banner.
            AlarmLockScreenView(info: AlarmActivityInfo(attributes: context.attributes, state: context.state))
                .environment(\.colorScheme, .dark)              // WHY: always our dark alarm look (#35)
                .activityBackgroundTint(Theme.Colors.alwaysDarkBackground)
                .activitySystemActionForegroundColor(Theme.Colors.accent)
        } dynamicIsland: { context in
            let info = AlarmActivityInfo(attributes: context.attributes, state: context.state)

            // 2. Dynamic Island (iPhone 14 Pro and newer).
            // LEARN: the island has 3 sizes: `expanded` (long-press), `compact` (two
            // small pieces around the camera) and `minimal` (one dot when 2 apps share it).
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AlarmIconBadge(info: info, size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmTimingText(info: info)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.Gradients.brand)
                        // WHY: "11:54 AM" was cut to "11:54…" in testing. Shrink to fit instead.
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(info.title)
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(info.subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: info.systemImage)
                    .foregroundStyle(Theme.Colors.accent)
            } compactTrailing: {
                AlarmTimingText(info: info, isCompact: true)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    // WHY a max width: a timer text is as wide as "00:00:00" by default,
                    // which would push the island too wide.
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: info.systemImage)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .keylineTint(Theme.Colors.accent)
        }
    }
}

// MARK: - Display info (a tiny "ViewModel" for the widget)

/// Turns AlarmKit's raw data into the few things our views show.
///
/// WHY a separate value: the lock screen and the Dynamic Island show the same facts.
/// Working them out once here keeps both views simple (same idea as the app's ViewModels).
struct AlarmActivityInfo {
    /// What the alarm is doing right now.
    enum Timing {
        /// Ringing. The time it was set for.
        case ringing(hour: Int, minute: Int)
        /// Snoozing: counts down to `until`, then rings again.
        case counting(until: Date)
        /// Countdown paused, with this many seconds left.
        case paused(remaining: TimeInterval)
    }

    let title: LocalizedStringResource
    let isBackup: Bool
    let timing: Timing

    init(attributes: AlarmAttributes<RiseUpAlarmMetadata>, state: AlarmPresentationState) {
        isBackup = attributes.metadata?.isBackup ?? false

        // LEARN: `switch` on an enum with associated values pulls the data out (`let ...`).
        switch state.mode {
        case .alert(let alert):
            title = attributes.presentation.alert.title
            timing = .ringing(hour: alert.time.hour, minute: alert.time.minute)
        case .countdown(let countdown):
            title = attributes.presentation.countdown?.title ?? "Snoozing"
            timing = .counting(until: countdown.fireDate)
        case .paused(let paused):
            title = attributes.presentation.paused?.title ?? "Paused"
            timing = .paused(remaining: paused.totalCountdownDuration - paused.previouslyElapsedDuration)
        @unknown default:
            // WHY: Apple may add new modes in a future iOS. We show something sensible.
            title = attributes.presentation.alert.title
            timing = .ringing(hour: 0, minute: 0)
        }
    }

    /// The SF Symbol for the current situation.
    var systemImage: String {
        switch timing {
        case .ringing: isBackup ? "bolt.fill" : "alarm.fill"
        case .counting: "zzz"
        case .paused: "pause.fill"
        }
    }

    /// One short line under the title.
    var subtitle: LocalizedStringResource {
        switch timing {
        case .ringing: isBackup ? "Open RiseUp and finish your mission" : "Time to rise and shine"
        case .counting: "Rings again soon"
        case .paused: "Snooze paused"
        }
    }
}

// MARK: - Small pieces

/// The ring time ("6:30 AM"), a live countdown ("4:59") or the paused time left.
struct AlarmTimingText: View {
    let info: AlarmActivityInfo
    /// The compact Dynamic Island has room for "6:30" but not "6:30 AM".
    var isCompact = false

    var body: some View {
        switch info.timing {
        case .ringing(let hour, let minute):
            // Build today's date at hour:minute only to FORMAT it in the user's style (12/24 h).
            let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
            // WHY two formats: in the compact island "11:42 AM" was cut to "11:42…" (seen in testing).
            // LEARN: `.hour(.defaultDigits(amPM: .omitted))` = the hour without "AM"/"PM".
            Text(date, format: isCompact ? .dateTime.hour(.defaultDigits(amPM: .omitted)).minute() : .dateTime.hour().minute())
                .monospacedDigit()
        case .counting(let until):
            // LEARN: `Text(_:style: .timer)` is updated by iOS every second, even though
            // our extension isn't running. Widgets can't run timers themselves.
            Text(until, style: .timer)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        case .paused(let remaining):
            Text(Duration.seconds(max(0, remaining)).formatted(.time(pattern: .minuteSecond)))
                .monospacedDigit()
        }
    }
}

/// The round gradient badge with the alarm icon.
struct AlarmIconBadge: View {
    let info: AlarmActivityInfo
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: info.systemImage)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.Gradients.brand, in: .circle)
    }
}

/// The lock screen banner.
struct AlarmLockScreenView: View {
    let info: AlarmActivityInfo

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AlarmIconBadge(info: info)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(info.title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(info.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.xs)

            AlarmTimingText(info: info)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.Gradients.brand)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Previews

// LEARN: Live Activity previews take the attributes (fixed) and a list of states
// (they change). Xcode shows one preview per state, so you see every look at once.
// TRY: change `isBackup` to true and watch the icon and subtitle change.
#Preview("Lock screen", as: .content, using: AlarmAttributes<RiseUpAlarmMetadata>(
    presentation: AlarmPresentation(
        alert: AlarmPresentation.Alert(
            title: "Gym",
            stopButton: AlarmButton(text: "Stop", textColor: Theme.Colors.textPrimary, systemImageName: "stop.fill")
        ),
        countdown: AlarmPresentation.Countdown(title: "Snoozing")
    ),
    metadata: RiseUpAlarmMetadata(wakeAlarmID: UUID(), isBackup: false),
    tintColor: Theme.Colors.accent
)) {
    AlarmLiveActivity()
} contentStates: {
    AlarmPresentationState(alarmID: UUID(), mode: .alert(.init(time: .init(hour: 6, minute: 30))))
    AlarmPresentationState(alarmID: UUID(), mode: .countdown(.init(
        totalCountdownDuration: 300, previouslyElapsedDuration: 0,
        startDate: .now, fireDate: .now.addingTimeInterval(300))))
    AlarmPresentationState(alarmID: UUID(), mode: .paused(.init(
        totalCountdownDuration: 300, previouslyElapsedDuration: 120)))
}
