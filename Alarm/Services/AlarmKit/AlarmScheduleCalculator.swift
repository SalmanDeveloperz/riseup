//
//  AlarmScheduleCalculator.swift
//  RiseUp
//
//  LAYER: Service (pure logic, no system APIs)
//  WHAT:  Date maths for alarms: "when does this alarm ring next?" and
//         "when should the backup alarms ring?".
//  USED BY: AlarmKitScheduler (backup chain), AlarmListViewModel (next alarm),
//           NextAlarmHeaderView + AlarmEditorView ("Rings in 7h 20m").
//
//  LEARN: "Pure" functions take input and return output without side effects
//  (no database, no network, no AlarmKit). They're the easiest code to unit-test,
//  so we keep tricky maths like this separate from the code that talks to iOS.
//

import Foundation

nonisolated enum AlarmScheduleCalculator {

    /// The next moment an alarm will ring, strictly after `date`.
    ///
    /// - Parameters:
    ///   - weekdays: repeat days. Empty = one-time alarm (next time the clock shows hour:minute).
    ///   - date: usually "now".
    /// - Returns: `nil` only if the calendar can't compute a date (should never happen).
    static func nextOccurrence(
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday>,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        if weekdays.isEmpty {
            // LEARN: `nextDate(after:matching:)` asks the calendar for the first future
            // date whose components match. That's "the next time it's 06:30".
            return calendar.nextDate(
                after: date,
                matching: DateComponents(hour: hour, minute: minute, second: 0),
                matchingPolicy: .nextTime
            )
        }

        // For repeating alarms: find the next date for EACH weekday and take the earliest.
        // LEARN: `compactMap` drops `nil`s; `min()` picks the earliest date.
        return weekdays
            .compactMap { weekday in
                calendar.nextDate(
                    after: date,
                    matching: DateComponents(hour: hour, minute: minute, second: 0, weekday: weekday.rawValue),
                    matchingPolicy: .nextTime
                )
            }
            .min()
    }

    /// Ring times for the backup chain: one date per offset after the main alarm.
    ///
    /// Example: main = 06:30, offsets = [1, 2, 3] → [06:31, 06:32, 06:33].
    static func backupDates(after mainDate: Date, offsetsInMinutes: [Int]) -> [Date] {
        offsetsInMinutes.map { mainDate.addingTimeInterval(TimeInterval($0 * 60)) }
    }

    /// "7h 20m", "2d 3h", "45m", or "less than a minute": how long until `fireDate`.
    ///
    /// ← USED BY: NextAlarmHeaderView (list header), AlarmEditorViewModel.ringsInText (editor)
    ///
    /// WHY round UP to the next minute: at 6:29:10 an alarm at 6:30 should read "1m", not "0m".
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
