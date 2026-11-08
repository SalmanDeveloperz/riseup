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
                                                 : AnyShapeStyle(Theme.Gradients.brand))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if let next {
                        Text("Rings in \(AlarmScheduleCalculator.countdownText(from: now, to: next.fireDate))")
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
