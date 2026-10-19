//
//  OnceAndDaysTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for "Once + days" (#36)
//  WHAT:  The negative-testing list, one test each:
//           • the extra ring is today if the time is still ahead, tomorrow if not, tomorrow at EXACTLY the time
//           • Once + Wed on a Wednesday (or on Tuesday after the time) rings ONCE, not twice
//           • after the extra ring, only the weekly days are left (and the alarm stays on)
//           • a passed extra ring is ignored everywhere and cleared by the sync and by "I'm up"
//           • one-time and quick alarms never get an extra ring
//           • the editor: saves it, reloads it, and never creates a NEW one by re-saving after it rang
//           • the widget timeline, the summaries, the database upgrade V3 → V4, the iOS alarm IDs
//  DATA:  in-memory databases, fixed dates (Mon 19 – Wed 21 Oct 2026).
//
//  CONNECTIONS:
//    → TESTS: AlarmScheduleCalculator, WakeAlarm (nextFireDate, upcomingOnceRing, separateOnceRing),
//             AlarmEditorViewModel, RingingViewModel, AlarmSyncService, WidgetBridge.plan,
//             Weekday.summary, RiseUpMigrationPlan, AlarmKitScheduler.onceRingID
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Once + days")
struct OnceAndDaysTests {
    let calendar = Calendar.current
    let repository: AlarmRepository
    let records: WakeRecordRepository
    let scheduler = MockAlarmScheduler()

    init() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
        records = WakeRecordRepository(context: container.mainContext)
    }

    /// LEARN: tests fix "now", so they give the same answer on any day. 19 Oct 2026 is a Monday.
    func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    /// "Wednesday 12:00 + once", with its extra ring planned from `now` (like the editor does on Save).
    func onceAndWednesday(now: Date) -> WakeAlarm {
        let alarm = WakeAlarm(hour: 12, minute: 0, repeatDays: [.wednesday])
        alarm.extraOnceDate = AlarmScheduleCalculator.onceRingDate(hour: 12, minute: 0, after: now, calendar: calendar)
        return alarm
    }

    // MARK: - When is the extra ring?

    @Test("Before the time → today; after → tomorrow; at EXACTLY the time → tomorrow")
    func onceRingDate() {
        #expect(AlarmScheduleCalculator.onceRingDate(hour: 12, minute: 0, after: date(19, 10, 0)) == date(19, 12, 0))
        #expect(AlarmScheduleCalculator.onceRingDate(hour: 12, minute: 0, after: date(19, 13, 0)) == date(20, 12, 0))
        #expect(AlarmScheduleCalculator.onceRingDate(hour: 12, minute: 0, after: date(19, 12, 0)) == date(20, 12, 0))
        #expect(AlarmScheduleCalculator.onceRingDate(hour: 0, minute: 0, after: date(19, 23, 59, 59)) == date(20, 0, 0))
    }

    @Test("Once + Wed on Monday: rings Monday 12:00, then Wednesdays (in that order)")
    func mondayRingsTodayThenWednesdays() {
        let alarm = onceAndWednesday(now: date(19, 10, 0))
        #expect(alarm.separateOnceRing(after: date(19, 10, 0), calendar: calendar) == date(19, 12, 0),
                "needs its own iOS alarm")
        #expect(alarm.nextFireDate(after: date(19, 10, 0)) == date(19, 12, 0))
        #expect(alarm.nextFireDate(after: date(19, 12, 0)) == date(21, 12, 0))
        #expect(alarm.nextFireDate(after: date(21, 12, 0)) == date(28, 12, 0))
    }

    @Test("Once + Wed on a Wednesday morning rings ONCE today, not twice")
    func wednesdayIsNotDoubled() {
        let now = date(21, 10, 0)
        let alarm = onceAndWednesday(now: now)
        #expect(alarm.extraOnceDate == date(21, 12, 0))
        #expect(alarm.separateOnceRing(after: now, calendar: calendar) == nil, "the weekly ring already covers it")
        #expect(alarm.nextFireDate(after: now) == date(21, 12, 0))
        #expect(alarm.nextFireDate(after: date(21, 12, 0)) == date(28, 12, 0), "no second ring today")
    }

    @Test("Once + Wed on Tuesday AFTER 12:00: the extra ring is Wednesday, so again only once")
    func tuesdayEveningIsNotDoubled() {
        let now = date(20, 13, 0)
        let alarm = onceAndWednesday(now: now)
        #expect(alarm.extraOnceDate == date(21, 12, 0))
        #expect(alarm.separateOnceRing(after: now, calendar: calendar) == nil)
    }

    @Test("After the extra ring only the weekly days are left")
    func passedOnceIsIgnored() {
        let alarm = onceAndWednesday(now: date(19, 10, 0))          // once = Mon 12:00
        let later = date(19, 15, 0)
        #expect(alarm.upcomingOnceRing(after: later) == nil)
        #expect(alarm.separateOnceRing(after: later, calendar: calendar) == nil)
        #expect(alarm.nextFireDate(after: later) == date(21, 12, 0))
    }

    @Test("One-time and quick alarms never get an extra ring")
    func onlyRepeatingAlarms() {
        let oneTime = WakeAlarm(hour: 12, minute: 0)
        oneTime.extraOnceDate = date(19, 12, 0)                     // even if a bad value got stored
        #expect(oneTime.upcomingOnceRing(after: date(19, 10, 0)) == nil)
        #expect(oneTime.nextFireDate(after: date(19, 10, 0)) == date(19, 12, 0))

        let quick = WakeAlarm(hour: 12, minute: 0, repeatDays: [.wednesday], fixedFireDate: date(19, 11, 0))
        quick.extraOnceDate = date(19, 12, 0)
        #expect(quick.upcomingOnceRing(after: date(19, 10, 0)) == nil)
        #expect(quick.nextFireDate(after: date(19, 10, 0)) == date(19, 11, 0))
    }

    @Test("Covered means: same weekday AND same time")
    func coverage() {
        #expect(AlarmScheduleCalculator.isCoveredByWeekly(date(21, 12, 0), hour: 12, minute: 0, weekdays: [.wednesday]))
        #expect(!AlarmScheduleCalculator.isCoveredByWeekly(date(20, 12, 0), hour: 12, minute: 0, weekdays: [.wednesday]))
        #expect(!AlarmScheduleCalculator.isCoveredByWeekly(date(21, 12, 30), hour: 12, minute: 0, weekdays: [.wednesday]))
    }

    // MARK: - Editor

    func makeEditor(alarmID: UUID? = nil) -> AlarmEditorViewModel {
        AlarmEditorViewModel(alarmID: alarmID, repository: repository, scheduler: scheduler,
                             settings: AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!),
                             wallpaperStore: MockWallpaperStore(), customSounds: MockCustomSoundLibrary(), coordinator: AppCoordinator())
    }

    @Test("Editor: only Once WITH days gives an extra ring")
    func editorNeedsDays() {
        let editor = makeEditor()
        editor.draft.hour = 12; editor.draft.minute = 0
        editor.draft.alsoOnce = true
        #expect(editor.resolvedExtraOnceDate(stored: nil, now: date(19, 10, 0), calendar: calendar) == nil, "no days = plain one-time")
        editor.draft.repeatDays = [.wednesday]
        #expect(editor.resolvedExtraOnceDate(stored: nil, now: date(19, 10, 0), calendar: calendar) == date(19, 12, 0))
        editor.draft.alsoOnce = false
        #expect(editor.resolvedExtraOnceDate(stored: nil, now: date(19, 10, 0), calendar: calendar) == nil)
    }

    @Test("Editor: saving, reloading, and re-saving after the extra ring rang")
    func editorRoundTrip() async throws {
        // 1. A new "Once + Wed" alarm at a time later today (or tomorrow): Save stores the extra ring.
        let editor = makeEditor()
        let soon = Date.now.addingTimeInterval(2 * 3600)
        let parts = calendar.dateComponents([.hour, .minute], from: soon)
        editor.draft.hour = parts.hour!; editor.draft.minute = parts.minute!
        editor.draft.repeatDays = [.wednesday]
        editor.draft.alsoOnce = true
        await editor.save()
        let alarm = try #require(repository.alarms.first)
        let stored = try #require(alarm.extraOnceDate)
        #expect(stored > .now)

        // 2. Reopen: "Once" is still on.
        let reopened = makeEditor(alarmID: alarm.id)
        #expect(reopened.draft.alsoOnce)
        #expect(reopened.repeatSummary.hasPrefix("Once + "))

        // 3. The trap: the extra ring rings while this editor stays open; saving afterwards
        //    without changes must NOT create a new one for tomorrow.
        #expect(reopened.resolvedExtraOnceDate(stored: stored, now: stored.addingTimeInterval(60)) == nil)
        // …but changing the time is a new request, so a new extra ring is planned.
        reopened.draft.hour = (reopened.draft.hour + 1) % 24
        #expect(reopened.resolvedExtraOnceDate(stored: stored, now: stored.addingTimeInterval(60)) != nil)
    }

    @Test("Editor: the sentence says today / tomorrow and never promises two rings")
    func editorSentence() {
        let editor = makeEditor()
        editor.draft.hour = 12; editor.draft.minute = 0
        editor.draft.repeatDays = [.wednesday]
        editor.draft.alsoOnce = true
        let monday = editor.onceAndDaysDetail(now: date(19, 10, 0), calendar: calendar) ?? ""
        #expect(monday.contains("once today") && monday.contains("every"))
        let mondayEvening = editor.onceAndDaysDetail(now: date(19, 18, 0), calendar: calendar) ?? ""
        #expect(mondayEvening.contains("once tomorrow"))
        let wednesday = editor.onceAndDaysDetail(now: date(21, 10, 0), calendar: calendar) ?? ""
        #expect(wednesday.contains("one of your days anyway"))
        editor.draft.alsoOnce = false
        #expect(editor.onceAndDaysDetail(now: date(19, 10, 0), calendar: calendar) == nil)
    }

    // MARK: - After it rang

    @Test("\"I'm up\" after the extra ring: it's cleared, the alarm stays on for its weekdays")
    func ringingClearsIt() async throws {
        let alarm = WakeAlarm(hour: 12, minute: 0, repeatDays: [.wednesday])
        alarm.extraOnceDate = Date.now.addingTimeInterval(-30)        // it just rang
        try repository.insert(alarm)
        let ringing = RingingViewModel(
            alarmID: alarm.id, repository: repository, records: records, scheduler: scheduler,
            audio: MockAudioService(), timeAnnouncer: MockTimeAnnouncer(), sleepSounds: MockSleepSoundPlayer(),
            settings: AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!),
            wallpaperStore: MockWallpaperStore(), customSounds: MockCustomSoundLibrary(), missionServices: .preview(), coordinator: AppCoordinator())
        ringing.start()
        await ringing.dismiss()
        #expect(alarm.extraOnceDate == nil)
        #expect(alarm.isEnabled, "the weekly Wednesdays go on")
    }

    @Test("Pressed Stop and never opened the app: the sync clears the passed extra ring")
    func syncClearsIt() async throws {
        let alarm = WakeAlarm(hour: 12, minute: 0, repeatDays: [.wednesday])
        alarm.extraOnceDate = Date.now.addingTimeInterval(-3600)
        try repository.insert(alarm)
        await AlarmSyncService(repository: repository, scheduler: scheduler).sync()
        #expect(alarm.extraOnceDate == nil)
        #expect(alarm.isEnabled)
        #expect(alarm.repeatSummary == Weekday.summary(for: [.wednesday]), "the card no longer says Once")
    }

    @Test("A still-to-come extra ring is kept by the sync")
    func syncKeepsFutureOnce() async throws {
        let alarm = WakeAlarm(hour: 12, minute: 0, repeatDays: [.wednesday])
        let future = Date.now.addingTimeInterval(3600)
        alarm.extraOnceDate = future
        try repository.insert(alarm)
        await AlarmSyncService(repository: repository, scheduler: scheduler).sync()
        #expect(alarm.extraOnceDate == future)
    }

    // MARK: - Everywhere else

    @Test("Widgets list the extra ring once, then the Wednesdays, never a double")
    func widgetTimeline() {
        let monday = onceAndWednesday(now: date(19, 10, 0))
        let rings = WidgetBridge.plan(alarms: [monday], defaultWallpaper: .standard, now: date(19, 10, 0), calendar: calendar)
            .map(\.event.fireDate)
        // The widget looks 8 days ahead (WidgetBridge.daysAhead): Mon 19 10:00 → Tue 27 10:00.
        #expect(rings == [date(19, 12, 0), date(21, 12, 0)])

        let wednesday = onceAndWednesday(now: date(21, 10, 0))
        let wedRings = WidgetBridge.plan(alarms: [wednesday], defaultWallpaper: .standard, now: date(21, 10, 0), calendar: calendar)
            .map(\.event.fireDate)
        #expect(wedRings.prefix(2) == [date(21, 12, 0), date(28, 12, 0)])
        #expect(Set(wedRings).count == wedRings.count, "no ring twice")
    }

    @Test("Summaries: \"Once + Wed\", and plain \"Once\" without days")
    func summaries() {
        #expect(Weekday.summary(for: [.wednesday], alsoOnce: true) == "Once + " + Weekday.wednesday.shortName)
        #expect(Weekday.summary(for: [.monday, .tuesday, .wednesday, .thursday, .friday], alsoOnce: true) == "Once + Weekdays")
        #expect(Weekday.summary(for: [], alsoOnce: true) == "Once")
    }

    @Test("The extra ring has its own iOS alarm ID, different from every other")
    func onceRingID() {
        let id = UUID()
        let others = [id, AlarmKitScheduler.snoozeID(for: id), AlarmKitScheduler.wakeUpCheckID(for: id)]
            + AlarmKitScheduler.backupOffsets.indices.map { AlarmKitScheduler.backupID(for: id, index: $0) }
        #expect(!others.contains(AlarmKitScheduler.onceRingID(for: id)))
        #expect(AlarmKitScheduler.onceRingID(for: id) == AlarmKitScheduler.onceRingID(for: id), "stable")
    }

    @Test("A real V3 database upgrades to V4 without losing alarms")
    func migrationV3toV4() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("RiseUp.store")
        let id = UUID()

        // 1. Yesterday's app: a V3 database with a weekly alarm.
        do {
            let v3 = Schema(versionedSchema: SchemaV3.self)
            let container = try ModelContainer(for: v3, configurations: [ModelConfiguration(schema: v3, url: url)])
            let context = ModelContext(container)
            context.insert(SchemaV3.WakeAlarm(id: id, hour: 7, minute: 30, repeatDays: [.wednesday],
                                              label: "Gym", wallpaperID: "live.aurora"))
            try context.save()
        }

        // 2. Today's app: V4 + the migration plan.
        let v4 = Schema(versionedSchema: SchemaV4.self)
        let container = try ModelContainer(for: v4, migrationPlan: RiseUpMigrationPlan.self,
                                           configurations: [ModelConfiguration(schema: v4, url: url)])
        let alarm = try #require(try ModelContext(container).fetch(FetchDescriptor<SchemaV4.WakeAlarm>()).first)
        #expect(alarm.id == id && alarm.hour == 7 && alarm.label == "Gym" && alarm.wallpaperID == "live.aurora")
        #expect(alarm.repeatDays == [.wednesday])
        #expect(alarm.extraOnceDate == nil, "old alarms get no extra ring")
    }
}
