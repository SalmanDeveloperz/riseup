//
//  MockAlarmScheduler.swift
//  RiseUp
//
//  LAYER: Service (fake implementation for Previews and tests)
//  WHAT:  Pretends to schedule alarms by just remembering IDs in memory.
//  USED BY: AppDependencies.preview(), unit tests.
//

import Foundation

/// A fake scheduler: no system alarms, no permission popups.
///
/// LEARN: Because ViewModels only know the `AlarmScheduling` protocol, they can't
/// tell this fake from the real thing. Tests can then check things like
/// "did saving the alarm call schedule?" by reading `scheduledIDs`.
final class MockAlarmScheduler: AlarmScheduling {
    var permission: AlarmPermission = .authorized
    private(set) var scheduledIDs: Set<UUID> = []
    private(set) var completedMissionIDs: [UUID] = []

    func requestPermission() async -> AlarmPermission { permission }

    func schedule(_ alarm: WakeAlarm) async throws {
        if alarm.isEnabled {
            scheduledIDs.insert(alarm.id)
        } else {
            scheduledIDs.remove(alarm.id)
        }
    }

    func cancel(_ alarm: WakeAlarm) {
        scheduledIDs.remove(alarm.id)
    }

    func missionCompleted(for alarm: WakeAlarm) async throws {
        completedMissionIDs.append(alarm.id)
    }

    func scheduledSystemAlarmIDs() -> Set<UUID> { scheduledIDs }

    /// The fake schedules instantly, so it's never "in the middle" of scheduling.
    func isScheduling(_ alarm: WakeAlarm) -> Bool { false }
}
