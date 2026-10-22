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
        let dates = AlarmScheduleCalculator.backupDates(after: main, offsets: [30, 60, 300])
        #expect(dates == [main.addingTimeInterval(30), date(2026, 10, 12, 6, 31), date(2026, 10, 12, 6, 35)])
    }

    // MARK: - Wake-up guarantee: "is a wake-up in progress?"

    private func isPending(_ backups: [Date], nextRing: Date?, now: Date) -> Bool {
        AlarmScheduleCalculator.isWakeUpPending(backupDates: backups, nextRing: nextRing, now: now,
                                                firstOffset: 30, window: 45 * 60)
    }

    @Test("Before the alarm rings, its armed chain is NOT a pending wake-up")
    func notPendingBeforeRing() {
        let ring = date(2026, 10, 12, 7, 0)
        let chain = AlarmScheduleCalculator.backupDates(after: ring, offsets: [30, 60, 120])
        #expect(!isPending(chain, nextRing: ring, now: date(2026, 10, 12, 6, 59)))
    }

    @Test("After the ring (next ring is tomorrow), the waiting chain IS pending")
    func pendingAfterRing() {
        let ring = date(2026, 10, 12, 7, 0)
        let chain = AlarmScheduleCalculator.backupDates(after: ring, offsets: [30, 60, 120])
        let now = ring.addingTimeInterval(10)
        #expect(isPending(chain, nextRing: date(2026, 10, 13, 7, 0), now: now))
    }

    @Test("A chain held back by the Ringing screen, or after a snooze, is still pending")
    func pendingWhenHeldOrSnoozed() {
        let now = date(2026, 10, 12, 7, 3)
        let held = AlarmScheduleCalculator.backupDates(after: now.addingTimeInterval(45), offsets: [30, 60])
        #expect(isPending(held, nextRing: date(2026, 10, 13, 7, 0), now: now))
        let snoozed = AlarmScheduleCalculator.backupDates(after: now.addingTimeInterval(20 * 60), offsets: [30, 60])
        #expect(isPending(snoozed, nextRing: date(2026, 10, 13, 7, 0), now: now))
    }

    @Test("A quick alarm that rang (no next ring) is pending while backups remain")
    func pendingQuickAlarm() {
        let now = date(2026, 10, 12, 7, 0, 10)
        #expect(isPending([now.addingTimeInterval(20)], nextRing: nil, now: now))
        #expect(!isPending([], nextRing: nil, now: now))
    }

    @Test("Stale backups hours away (time-zone change) don't lock the alarm")
    func staleBackupsAreNotPending() {
        let now = date(2026, 10, 12, 4, 0)
        let stale = [date(2026, 10, 12, 7, 0, 30)]      // the old chain, 3 h away
        #expect(!isPending(stale, nextRing: date(2026, 10, 12, 6, 0), now: now))
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
        let backups = AlarmKitScheduler.backupOffsets.indices.map { AlarmKitScheduler.backupID(for: alarmID, index: $0) }
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
