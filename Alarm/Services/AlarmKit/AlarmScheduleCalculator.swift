//
//  AlarmScheduleCalculator.swift
//  RiseUp
//
//  LAYER: Service (pure logic, no system APIs)
//  WHAT:  Date maths for alarms: "when does this alarm ring next?",
//         "when should the backup alarms ring?" and "is a wake-up still in progress?".
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

    // MARK: - "Once + days" (#36)

    /// The moment of the extra one-time ring: the next hour:minute strictly after `date`
    /// (today if that time is still ahead, otherwise tomorrow).
    ///
    /// WHY "strictly after": saving at exactly 12:00:00 for a 12:00 alarm means the NEXT 12:00
    /// (tomorrow), never "right now" (iOS can't ring in the past).
    /// ← USED BY: AlarmEditorViewModel (on Save)
    static func onceRingDate(hour: Int, minute: Int, after date: Date, calendar: Calendar = .current) -> Date? {
        nextOccurrence(hour: hour, minute: minute, weekdays: [], after: date, calendar: calendar)
    }

    /// Is this once-ring ALSO one of the weekly rings? Then it must ring only once, not twice.
    /// Example: Once + Wednesday saved on a Wednesday morning for 12:00 → "once today" IS "this Wednesday".
    ///
    /// ← USED BY: WakeAlarm.separateOnceRing → AlarmKitScheduler (no second iOS alarm for it)
    static func isCoveredByWeekly(_ onceDate: Date, hour: Int, minute: Int, weekdays: Set<Weekday>,
                                  calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: onceDate)
        guard let number = parts.weekday, let weekday = Weekday(rawValue: number) else { return false }
        return weekdays.contains(weekday) && parts.hour == hour && parts.minute == minute
    }

    /// Ring times for the backup chain: one date per offset (in SECONDS) after a ring.
    ///
    /// Example: ring = 06:30:00, offsets = [30, 60, 120] → [06:30:30, 06:31:00, 06:32:00].
    static func backupDates(after ringDate: Date, offsets: [TimeInterval]) -> [Date] {
        offsets.map { ringDate.addingTimeInterval($0) }
    }

    /// Is a wake-up "in progress" for an alarm? (It rang, and its backup chain is still waiting.)
    ///
    /// iOS doesn't tell us when an alarm rang, so we read it from the backups that are left:
    /// a backup that rings EARLIER than the chain of the alarm's next ring must belong to a ring
    /// that already happened (or a snooze, or a chain held back by the Ringing screen).
    ///
    /// - Parameters:
    ///   - backupDates: the dates of this alarm's backups that iOS still has.
    ///   - nextRing: when the alarm itself rings next (`nil` = never again, e.g. a quick alarm that rang).
    ///   - firstOffset: the chain's first offset (30 s): the next ring's chain starts at `nextRing + firstOffset`.
    ///   - window: only backups this close to `now` count. WHY: after flying to another time zone the
    ///     main alarm moves but fixed backups don't; those stale ones are hours away and must not
    ///     lock the alarm (the sync re-arms them instead).
    ///
    /// ← USED BY: AlarmKitScheduler.hasPendingWakeUp (tests: ScheduleCalculatorTests)
    static func isWakeUpPending(backupDates: [Date], nextRing: Date?, now: Date,
                                firstOffset: TimeInterval, window: TimeInterval) -> Bool {
        let nextChainStart = nextRing?.addingTimeInterval(firstOffset)
        return backupDates.contains { date in
            guard date.timeIntervalSince(now) <= window else { return false }   // far away: not this wake-up
            guard let nextChainStart else { return true }                        // no next ring: any backup = pending
            return date < nextChainStart.addingTimeInterval(-1)                  // earlier than the next ring's chain
        }
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
