//
//  LaunchReadinessTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for the pre-launch review fixes (2026-10-13)
//  WHAT:  • every alarm sound in the catalog has its audio file in the app
//         • switching an alarm ON then quickly OFF never leaves a "ghost" alarm in iOS
//         • the database recovery helper exists and in-memory databases still open
//  DATA:  in-memory database.
//
//  CONNECTIONS:
//    → TESTS: AlarmSound, AlarmListViewModel (+ MockAlarmScheduler with a delay)
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Launch readiness")
struct LaunchReadinessTests {

    @Test("Every alarm sound has its file in the app", arguments: AlarmSound.allCases.filter { $0 != .systemDefault })
    func alarmSoundFileExists(sound: AlarmSound) {
        let base = (sound.rawValue as NSString).deletingPathExtension
        #expect(Bundle.main.url(forResource: base, withExtension: "caf") != nil)
    }

    @Test("Every alarm sound appears in exactly one picker group")
    func soundGroups() {
        let listed = AlarmSound.Category.allCases.flatMap(\.sounds)
        #expect(listed.count == AlarmSound.allCases.count)
        #expect(Set(listed) == Set(AlarmSound.allCases))
    }

    @Test("Switching an alarm ON then quickly OFF leaves nothing scheduled in iOS")
    func noGhostAlarm() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = AlarmRepository(context: container.mainContext)
        let scheduler = MockAlarmScheduler()
        scheduler.scheduleDelay = .milliseconds(200)          // iOS is "slow" today
        let viewModel = AlarmListViewModel(
            repository: repository, scheduler: scheduler,
            sync: AlarmSyncService(repository: repository, scheduler: scheduler),
            coordinator: AppCoordinator()
        )
        let alarm = WakeAlarm(hour: 7, minute: 0, isEnabled: false)
        try repository.insert(alarm)

        let turnOn = Task { await viewModel.setEnabled(true, alarmID: alarm.id) }
        try await Task.sleep(for: .milliseconds(50))
        await viewModel.setEnabled(false, alarmID: alarm.id)  // the user changes their mind
        await turnOn.value
        try await Task.sleep(for: .milliseconds(500))         // let the queued change finish

        #expect(repository.alarms.first?.isEnabled == false)
        #expect(!scheduler.scheduledIDs.contains(alarm.id), "the card says OFF, so iOS must have nothing")
    }
}
