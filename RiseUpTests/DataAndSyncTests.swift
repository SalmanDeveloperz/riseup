//
//  DataAndSyncTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for the Repository + Service layers
//  WHAT:  Uses a REAL SwiftData database (in memory) and the FAKE scheduler to check:
//           • AlarmRepository keeps `alarms` up to date and stores missions in order
//           • WakeRecordRepository reuses one record per wake-up
//           • AlarmSyncService's rules (quick alarms deleted, one-time switched off, …)
//           • AppSettings remembers values
//  DATA:  an in-memory database that disappears after each test.
//
//  CONNECTIONS:
//    → TESTS: AlarmRepository, WakeRecordRepository, AlarmSyncService, AppSettings
//    → USES:  ModelContainerFactory.make(inMemory: true), MockAlarmScheduler
//
//  LEARN: Why the fake scheduler matters here
//  ──────────────────────────────────────────
//  AlarmSyncService only knows the `AlarmScheduling` protocol. In the app it talks to iOS;
//  here we hand it `MockAlarmScheduler`, which just remembers IDs. So we can test the RULES
//  ("a one-time alarm missing in iOS gets switched off") without real alarms ringing.
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Repositories and sync")
struct DataAndSyncTests {
    let container: ModelContainer
    let repository: AlarmRepository
    let records: WakeRecordRepository
    let scheduler: MockAlarmScheduler
    let sync: AlarmSyncService

    /// LEARN: Swift Testing creates a NEW instance of this struct for every test, so each
    /// test starts with an empty database (nothing leaks between tests).
    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
        records = WakeRecordRepository(context: container.mainContext)
        scheduler = MockAlarmScheduler()
        sync = AlarmSyncService(repository: repository, scheduler: scheduler)
    }

    // MARK: - AlarmRepository

    @Test("Inserting and deleting keeps the live list up to date")
    func insertDelete() throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        #expect(repository.alarms.map(\.id) == [alarm.id])
        try repository.delete(alarm)
        #expect(repository.alarms.isEmpty)
    }

    @Test("Missions are stored in the order of the drafts, with their payloads")
    func replaceMissions() throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        var photo = MissionDraft.defaults(for: .photo)
        photo.dataPayload = Data([9, 9])
        let drafts = [MissionDraft.defaults(for: .shake), MissionDraft.defaults(for: .math), photo]

        repository.replaceMissions(of: alarm, with: drafts)
        try repository.save()

        let saved = try #require(try repository.fetch(id: alarm.id))
        #expect(saved.sortedMissions.map(\.type) == [.shake, .math, .photo])
        #expect(saved.sortedMissions.last?.dataPayload == Data([9, 9]))
        // Round trip: database row → draft keeps everything.
        #expect(MissionDraft(saved.sortedMissions[2]).dataPayload == Data([9, 9]))

        // Replacing again doesn't leave old rows behind.
        repository.replaceMissions(of: alarm, with: [MissionDraft.defaults(for: .typing)])
        try repository.save()
        #expect(try repository.fetch(id: alarm.id)?.missions.count == 1)
    }

    // MARK: - WakeRecordRepository

    @Test("Snoozing reuses the same wake-up record instead of creating a new one")
    func recordReuse() throws {
        let id = UUID()
        let first = try records.openRecord(alarmID: id, alarmTitle: "Gym")
        let second = try records.openRecord(alarmID: id, alarmTitle: "Gym")
        #expect(first.id == second.id)

        first.dismissedAt = .now
        try records.save()
        let next = try records.openRecord(alarmID: id, alarmTitle: "Gym")
        #expect(next.id != first.id, "a finished record must not be reused")
    }

    // MARK: - AlarmSyncService rules

    @Test("Rule 1: a one-time alarm missing in iOS has rung → switched off")
    func oneTimeSwitchedOff() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, isEnabled: true)
        try repository.insert(alarm)          // in the database, but never given to the scheduler

        await sync.sync()

        #expect(try repository.fetch(id: alarm.id)?.isEnabled == false)
    }

    @Test("Rule 1: a repeating alarm missing in iOS is scheduled again")
    func repeatingRescheduled() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, repeatDays: [.monday], isEnabled: true)
        try repository.insert(alarm)

        await sync.sync()

        #expect(scheduler.scheduledIDs.contains(alarm.id))
        #expect(try repository.fetch(id: alarm.id)?.isEnabled == true)
    }

    @Test("Rule 1: a quick alarm that already rang is deleted")
    func quickAlarmDeleted() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, label: "Quick alarm", fixedFireDate: .now.addingTimeInterval(-60))
        try repository.insert(alarm)

        await sync.sync()

        #expect(repository.alarms.isEmpty)
    }

    @Test("Rule 3: system alarms that belong to no alarm are cancelled")
    func orphansCancelled() async throws {
        let ghost = WakeAlarm(hour: 5, minute: 0)        // never saved to the database
        try await scheduler.schedule(ghost)
        let kept = WakeAlarm(hour: 6, minute: 0, repeatDays: [.monday])
        try repository.insert(kept)
        try await scheduler.schedule(kept)

        await sync.sync()

        #expect(!scheduler.scheduledIDs.contains(ghost.id))
        #expect(scheduler.scheduledIDs.contains(kept.id))
    }

    @Test("Switched-off alarms are left alone")
    func disabledUntouched() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, isEnabled: false)
        try repository.insert(alarm)

        await sync.sync()

        #expect(repository.alarms.count == 1)
        #expect(!scheduler.scheduledIDs.contains(alarm.id))
    }

    // MARK: - AppSettings

    @Test("Settings are remembered and have sensible defaults")
    func settingsDefaults() {
        // A private store so the test never touches the real app's settings.
        let store = UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!
        let settings = AppSettings(store: store)
        #expect(settings.hasCompletedOnboarding == false)
        #expect(settings.speaksTimeWhileRinging == true)

        settings.hasCompletedOnboarding = true
        settings.defaultSound = .siren
        let reloaded = AppSettings(store: store)
        #expect(reloaded.hasCompletedOnboarding)
        #expect(reloaded.defaultSound == .siren)
    }
}
