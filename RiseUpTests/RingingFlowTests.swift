//
//  RingingFlowTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for the most important ViewModel: the wake-up itself
//  WHAT:  Runs RingingViewModel with fakes (no real alarm, sound or speech) and checks:
//           • "I'm up" ends in .success and saves a finished WakeRecord
//           • a one-time alarm is switched off afterwards, a quick alarm is deleted
//           • the Wake-Up Check is scheduled for normal alarms, but NEVER for quick alarms
//           • the snooze limit is respected
//  DATA:  in-memory database.
//
//  CONNECTIONS:
//    → TESTS: RingingViewModel (+ AlarmRepository, WakeRecordRepository, MockAlarmScheduler)
//
//  WHY: the Simulator test showed a quick alarm promising a wake-up check that never rang.
//  These tests make sure that can't come back, without waiting minutes for real alarms.
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Ringing flow")
struct RingingFlowTests {
    let repository: AlarmRepository
    let records: WakeRecordRepository
    let scheduler = MockAlarmScheduler()

    init() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
        records = WakeRecordRepository(context: container.mainContext)
    }

    func makeViewModel(for alarm: WakeAlarm) -> RingingViewModel {
        RingingViewModel(
            alarmID: alarm.id,
            repository: repository,
            records: records,
            scheduler: scheduler,
            audio: MockAudioService(),
            timeAnnouncer: MockTimeAnnouncer(),
            settings: AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!),
            missionServices: .preview(),
            coordinator: AppCoordinator()
        )
    }

    @Test("I'm up → success, record finished, one-time alarm switched off, wake-up check scheduled")
    func oneTimeAlarm() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, wakeUpCheckMinutes: 5)
        try repository.insert(alarm)
        let viewModel = makeViewModel(for: alarm)

        viewModel.start()
        await viewModel.dismiss()

        guard case .success(let summary) = viewModel.phase else {
            Issue.record("expected the success phase, got \(viewModel.phase)")
            return
        }
        #expect(summary.wakeUpCheckMinutes == 5)
        #expect(scheduler.wakeUpChecks[alarm.id] == 5)
        #expect(try repository.fetch(id: alarm.id)?.isEnabled == false)
        #expect(try records.recent(limit: 1).first?.dismissedAt != nil)
    }

    @Test("A quick alarm is deleted after waking up and never gets a wake-up check")
    func quickAlarm() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, label: "Quick alarm", wakeUpCheckMinutes: 5,
                              fixedFireDate: .now.addingTimeInterval(-10))
        try repository.insert(alarm)
        let viewModel = makeViewModel(for: alarm)

        viewModel.start()
        await viewModel.dismiss()

        guard case .success(let summary) = viewModel.phase else {
            Issue.record("expected the success phase")
            return
        }
        #expect(summary.wakeUpCheckMinutes == 0, "Success must not promise a check that can't ring")
        #expect(scheduler.wakeUpChecks[alarm.id] == nil)
        #expect(repository.alarms.isEmpty)
    }

    @Test("Snooze stops being offered at the limit")
    func snoozeLimit() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, maxSnoozeCount: 1)
        try repository.insert(alarm)

        let first = makeViewModel(for: alarm)
        first.start()
        #expect(first.canSnooze)
        await first.snooze()

        // The alarm rings again → a new ringing screen, same wake-up record.
        let second = makeViewModel(for: alarm)
        second.start()
        #expect(second.snoozeCount == 1)
        #expect(!second.canSnooze)
    }

    @Test("Mission alarms can't snooze and start with the first mission")
    func missionAlarm() throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        repository.replaceMissions(of: alarm, with: [MissionDraft.defaults(for: .math)])
        try repository.save()
        let viewModel = makeViewModel(for: alarm)

        viewModel.start()
        #expect(!viewModel.canSnooze)
        viewModel.startMissions()
        #expect(viewModel.currentMission?.type == .math)
        #expect(viewModel.isQuiet, "the alarm goes quiet while the user works")
    }
}
