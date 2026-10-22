//
//  HealthCheckTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for a ViewModel
//  WHAT:  "Check my alarms" (Screen #28) puts problems first, tips last, and its header
//         says "Everything looks good" when nothing is wrong.
//  DATA:  in-memory database + fake scheduler.
//
//  CONNECTIONS:
//    → TESTS: AlarmHealthCheckViewModel
//
//  WHY this test exists: while testing in the Simulator, tips were listed above the green
//  checks and the header showed a lightbulb. This test makes sure that bug can't come back.
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Check my alarms")
struct HealthCheckTests {
    let repository: AlarmRepository
    let scheduler = MockAlarmScheduler()
    let viewModel: AlarmHealthCheckViewModel

    init() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
        viewModel = AlarmHealthCheckViewModel(
            repository: repository,
            scheduler: scheduler,
            sync: AlarmSyncService(repository: repository, scheduler: scheduler),
            stepCounter: MockStepCounter(),
            coordinator: AppCoordinator()
        )
    }

    @Test("All good: header says so, and green checks come before tips")
    func allGood() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, repeatDays: [.monday])
        try repository.insert(alarm)
        try await scheduler.schedule(alarm)

        viewModel.refresh()

        #expect(viewModel.overallStatus == .ok)
        #expect(viewModel.headline == "Everything looks good")
        let statuses = viewModel.checks.map(\.status)
        #expect(statuses == statuses.sorted(by: >), "sorted worst → best, tips last")
        #expect(statuses.last == .info)
    }

    @Test("An enabled alarm missing in iOS is a problem with a Repair button, listed first")
    func missingAlarm() throws {
        try repository.insert(WakeAlarm(hour: 7, minute: 0, repeatDays: [.monday]))   // never scheduled

        viewModel.refresh()

        #expect(viewModel.overallStatus == .problem)
        #expect(viewModel.checks.first?.fix == .repairSchedule)
    }

    @Test("Denied permission is a problem that offers Open Settings")
    func deniedPermission() {
        scheduler.permission = .denied

        viewModel.refresh()

        #expect(viewModel.checks.first?.fix == .openSettings)
    }
}
