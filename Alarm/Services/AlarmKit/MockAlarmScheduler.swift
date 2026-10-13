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

    /// Tests can make scheduling "slow" like the real AlarmKit, to reproduce race conditions.
    var scheduleDelay: Duration?

    func schedule(_ alarm: WakeAlarm) async throws {
        // Like the real scheduler: decide first; only switching ON waits for iOS
        // (switching off just cancels, instantly).
        let wantsOn = alarm.isEnabled
        let id = alarm.id
        if wantsOn, let scheduleDelay { try? await Task.sleep(for: scheduleDelay) }
        if wantsOn {
            scheduledIDs.insert(id)
        } else {
            scheduledIDs.remove(id)
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

    func systemAlarms() -> [UUID: SystemAlarmInfo] {
        Dictionary(uniqueKeysWithValues: scheduledIDs.map { ($0, SystemAlarmInfo(state: .scheduled, fixedDate: nil)) })
    }

    func systemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> { [alarm.id] }

    func ringingSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> { [alarm.id] }
    func backupSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID> { [] }

    /// Alarms that got a wake-up check, with its minutes (tests can check it).
    private(set) var wakeUpChecks: [UUID: Int] = [:]

    func scheduleWakeUpCheck(for alarm: WakeAlarm, minutes: Int) async throws {
        wakeUpChecks[alarm.id] = minutes
    }

    func stopWakeUpCheckIfRinging(for alarm: WakeAlarm) -> Bool { false }

    func stopRinging(_ alarm: WakeAlarm) {}

    func scheduleSnooze(for alarm: WakeAlarm, minutes: Int) async throws {}

    func ensureBackupChain(for alarm: WakeAlarm) async throws {}

    func cancelSystemAlarms(notIn keeping: Set<UUID>) {
        scheduledIDs = scheduledIDs.intersection(keeping)
    }

    func hasPendingMission(_ alarm: WakeAlarm, now: Date) -> Bool { false }
}
