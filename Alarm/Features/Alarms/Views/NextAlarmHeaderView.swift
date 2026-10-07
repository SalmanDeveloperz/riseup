//
//  NextAlarmHeaderView.swift
//  RiseUp
//
//  LAYER: View (part of the Alarm List screen)
//  WHAT:  The top banner: "Rings in 7h 20m" + which alarm, or "No alarms on".
//  DATA:  none stored; it only displays what it's given.
//
//  CONNECTIONS:
//    ← USED BY:  AlarmListView, inside `TimelineView(.everyMinute)`
//    ← INPUT:    `next` comes from AlarmListViewModel.nextAlarm(after:)
//                `now`  comes from TimelineView (the current minute)
//
//  LEARN: This is a "dumb" view: plain `let` inputs, no ViewModel, no state.
//  Dumb views are easy to preview and reuse. The smart work (finding the next alarm)
//  happens in the ViewModel.
//

import SwiftUI

struct NextAlarmHeaderView: View {
    /// The next alarm to ring and when, or `nil` if every alarm is off.
    /// (A value snapshot, not a database object; see AlarmRow.swift.)
    let next: NextAlarmInfo?
    /// The current time, used to compute "in 7h 20m".
    let now: Date

    var body: some View {
        GlowCard(isGlowing: next != nil) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: next == nil ? "moon.zzz.fill" : "alarm.waves.left.and.right.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(next == nil ? AnyShapeStyle(Theme.Colors.textTertiary)
                                                 : AnyShapeStyle(Theme.Gradients.sunrise))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if let next {
                        Text("Rings in \(Self.countdownText(from: now, to: next.fireDate))")
                            .font(.riseTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        // LEARN: `Date.formatted(...)` builds localized text like "Tue 6:30 AM".
                        Text("\(next.fireDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())) · \(next.title)")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        Text("No alarms on")
                            .font(.riseTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Switch one on, or tap + to create one.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    /// "7h 20m", "2d 3h", "45m", or "less than a minute".
    ///
    /// WHY round UP to the next minute: at 6:29:10 an alarm at 6:30 should read "1m", not "0m".
    /// LEARN: `static func` belongs to the type, not to one instance. It uses no
    /// view state, which makes it easy to unit-test later.
    static func countdownText(from now: Date, to fireDate: Date) -> String {
        let totalMinutes = Int((fireDate.timeIntervalSince(now) / 60).rounded(.up))
        guard totalMinutes > 0 else { return "less than a minute" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        NextAlarmHeaderView(
            next: NextAlarmInfo(title: "Gym", fireDate: .now.addingTimeInterval(7 * 3600 + 20 * 60)),
            now: .now
        )
        NextAlarmHeaderView(next: nil, now: .now)
    }
    .padding()
    .appBackground()
}
