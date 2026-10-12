//
//  ScheduleCalculatorTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing)
//  WHAT:  Checks the date maths every alarm depends on: "when does it ring next?",
//         backup times, the "Rings in 7h 20m" text and the derived system-alarm IDs.
//  DATA:  none (pure functions, a fixed calendar).
//
//  CONNECTIONS:
//    → TESTS: AlarmScheduleCalculator, AlarmKitScheduler's static ID helpers
//
//  LEARN: How to run tests
//  ───────────────────────
//  In Xcode press ⌘U (Product → Test). Each `@Test` function runs on its own and shows a
//  green ✓ or red ✗ in the Test navigator (⌘6). `#expect(...)` is a check: if it's false,
//  the test fails and Xcode shows the actual values next to the line.
//
//  WHY a fixed calendar (UTC, Gregorian): tests must give the same answer on every
//  Mac and iPhone, in any time zone. Otherwise a test could pass in Karachi and fail in London.
//

import Foundation
import Testing
@testable import Alarm

@Suite("Alarm schedule maths")
struct ScheduleCalculatorTests {

    /// A calendar that never changes: Gregorian, UTC.
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Builds a date like 2026-10-12 06:00 (UTC). 2026-10-12 is a Monday.
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: - nextOccurrence

    @Test("One-time alarm later today rings today")
    func oneTimeLaterToday() {
        let next = AlarmScheduleCalculator.nextOccurrence(
            hour: 7, minute: 30, weekdays: [], after: date(2026, 10, 12, 6, 0), calendar: calendar)
        #expect(next == date(2026, 10, 12, 7, 30))
    }

    @Test("One-time alarm earlier today rings tomorrow")
    func oneTimeTomorrow() {
        let next = AlarmScheduleCalculator.nextOccurrence(
            hour: 5, minute: 0, weekdays: [], after: date(2026, 10, 12, 6, 0), calendar: calendar)
        #expect(next == date(2026, 10, 13, 5, 0))
    }

    @Test("At exactly the ring time, the NEXT occurrence is returned (strictly after)")
    func exactTimeIsNotNext() {
        let next = AlarmScheduleCalculator.nextOccurrence(
            hour: 6, minute: 0, weekdays: [], after: date(2026, 10, 12, 6, 0), calendar: calendar)
        #expect(next == date(2026, 10, 13, 6, 0))
    }

    @Test("Weekend alarm on a Monday rings on Saturday")
    func weekendFromMonday() {
        let next = AlarmScheduleCalculator.nextOccurrence(
            hour: 9, minute: 0, weekdays: [.saturday, .sunday], after: date(2026, 10, 12, 8, 0), calendar: calendar)
        #expect(next == date(2026, 10, 17, 9, 0))   // Saturday 17 Oct
    }

    @Test("Weekday alarm on Friday evening rings on Monday")
    func weekdaysFromFridayEvening() {
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let next = AlarmScheduleCalculator.nextOccurrence(
            hour: 6, minute: 30, weekdays: weekdays, after: date(2026, 10, 16, 20, 0), calendar: calendar)
        #expect(next == date(2026, 10, 19, 6, 30))  // Monday 19 Oct
    }

    // MARK: - Backups & countdown

    @Test("Backup times are the offsets after the main ring")
    func backupDates() {
        let main = date(2026, 10, 12, 6, 30)
        let dates = AlarmScheduleCalculator.backupDates(after: main, offsetsInMinutes: [1, 2, 5])
        #expect(dates == [date(2026, 10, 12, 6, 31), date(2026, 10, 12, 6, 32), date(2026, 10, 12, 6, 35)])
    }

    // LEARN: `arguments:` runs the same test once per value. Here: 4 small tests in one.
    @Test("Countdown text", arguments: [
        (61.0, "2m"),               // 1 min 1 s → rounds UP
        (3600.0, "1h 0m"),
        (7.5 * 3600, "7h 30m"),
        (26 * 3600.0, "1d 2h"),
    ])
    func countdownText(seconds: Double, expected: String) {
        let now = date(2026, 10, 12, 6, 0)
        #expect(AlarmScheduleCalculator.countdownText(from: now, to: now.addingTimeInterval(seconds)) == expected)
    }

    @Test("Countdown for a time in the past says less than a minute")
    func countdownPast() {
        let now = date(2026, 10, 12, 6, 0)
        #expect(AlarmScheduleCalculator.countdownText(from: now, to: now.addingTimeInterval(-30)) == "less than a minute")
    }

    // MARK: - Derived system alarm IDs

    @Test("Backup, snooze and wake-up-check IDs are all different and stable")
    func derivedIDs() {
        let alarmID = UUID()
        let backups = AlarmKitScheduler.backupOffsetsInMinutes.indices.map { AlarmKitScheduler.backupID(for: alarmID, index: $0) }
        let snooze = AlarmKitScheduler.snoozeID(for: alarmID)
        let check = AlarmKitScheduler.wakeUpCheckID(for: alarmID)

        let all = [alarmID] + backups + [snooze, check]
        #expect(Set(all).count == all.count, "every ID must be unique")
        // Same input → same output, so we can always find them again after an app restart.
        #expect(AlarmKitScheduler.backupID(for: alarmID, index: 0) == backups[0])
        #expect(AlarmKitScheduler.snoozeID(for: alarmID) == snooze)
    }

    @Test("Lab test IDs are recognised, normal IDs are not")
    func labIDs() {
        #expect(AlarmKitScheduler.isLabTestID(AlarmKitScheduler.makeLabTestID()))
        var bytes = UUID().uuid
        bytes.0 = 0x00
        #expect(!AlarmKitScheduler.isLabTestID(UUID(uuid: bytes)))
    }
}
