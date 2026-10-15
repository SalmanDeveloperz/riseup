//
//  AlarmScheduling.swift
//  RiseUp
//
//  LAYER: Service (protocol)
//  WHAT:  The "contract" for anything that can schedule alarms with the system.
//  USED BY: ViewModels (through AppDependencies). Implemented by AlarmKitScheduler (real)
//           and MockAlarmScheduler (previews/tests).
//
//  LEARN: Why a protocol?
//  ──────────────────────
//  A protocol lists WHAT something can do, not HOW. ViewModels depend on
//  `any AlarmScheduling`, not on AlarmKit directly. In the real app we pass the real
//  AlarmKit scheduler; in SwiftUI Previews we pass a fake one, so previews never
//  schedule real alarms on your phone and still render instantly.
//

import Foundation

/// Whether the user allowed RiseUp to schedule alarms.
///
/// WHY our own enum instead of AlarmKit's? So ViewModels and Views never need to
/// `import AlarmKit`. Only the scheduler talks to Apple's framework.
nonisolated enum AlarmPermission: Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Thrown when the user hasn't allowed RiseUp to schedule alarms.
///
/// ← THROWN BY: AlarmScheduling.requirePermission() (below)
/// ← SHOWN BY:  AlarmListViewModel and AlarmEditorViewModel alerts
///
/// LEARN: conforming to `LocalizedError` and providing `errorDescription` makes
/// `error.localizedDescription` return OUR friendly text instead of a technical one.
nonisolated enum AlarmPermissionError: LocalizedError {
    case denied

    var errorDescription: String? {
        "RiseUp isn't allowed to schedule alarms. Turn it on in Settings → RiseUp → Alarms."
    }
}

/// What iOS is doing with one system alarm right now.
/// WHY our own types: ViewModels and services never import AlarmKit (see AlarmPermission).
nonisolated enum SystemAlarmState: Sendable {
    case scheduled   // waiting for its time
    case countdown   // snoozing (system Snooze button)
    case paused
    case alerting    // RINGING right now
}

/// One system alarm as iOS reports it.
nonisolated struct SystemAlarmInfo: Sendable {
    var state: SystemAlarmState
    /// The exact ring moment for one-time (`.fixed`) alarms: backups, snoozes, quick alarms.
    /// `nil` for clock-time (`.relative`) alarms.
    var fixedDate: Date?
}

/// Schedules and cancels RiseUp alarms with the operating system.
protocol AlarmScheduling: AnyObject {           // AnyObject means just class can conform this protocol
    /// Current permission state (no popup).
    var permission: AlarmPermission { get }

    /// Shows the system "Allow alarms?" popup the first time; afterwards returns the saved answer.
    func requestPermission() async -> AlarmPermission

    /// Schedules (or re-schedules) an alarm. Replaces anything previously scheduled for it.
    /// Disabled alarms are just cancelled.
    func schedule(_ alarm: WakeAlarm) async throws

    /// Removes the alarm and its backup chain from the system.
    func cancel(_ alarm: WakeAlarm)

    /// Called when the user is up (missions done, or "I'm up"): stops the backup chain and,
    /// for repeating alarms, arms a fresh chain for the next occurrence.
    func wakeUpCompleted(for alarm: WakeAlarm) async throws

    /// IDs of every alarm currently scheduled with the system (main + backups).
    /// ← USED BY: AlarmListViewModel's reconcile step, and the AlarmKit Lab.
    func scheduledSystemAlarmIDs() -> Set<UUID>

    /// True while `schedule(alarm)` is still running for this alarm.
    ///
    /// WHY: scheduling takes a moment (several calls into iOS). During that time the alarm
    /// is already "on" in our database but not yet in iOS's list. Code that compares the
    /// two (the reconcile step) must skip it, or it would wrongly switch the alarm off.
    /// See "race condition" in docs/HOW_IT_WORKS.md.
    func isScheduling(_ alarm: WakeAlarm) -> Bool

    // MARK: Added in Phase 1/2 (sync, ringing, snooze)

    /// Every RiseUp system alarm iOS knows about, with its state and exact date (if fixed).
    /// ← USED BY: AlarmSyncService (reconcile, "is something ringing?", orphans), hasPendingWakeUp
    func systemAlarms() -> [UUID: SystemAlarmInfo]

    /// Every system alarm ID that can belong to this WakeAlarm: main, each backup, snooze,
    /// and the wake-up check.
    /// ← USED BY: AlarmSyncService (which system alarms to KEEP when cleaning up)
    func systemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID>

    /// The IDs whose ringing means "do the wake-up now": main, backups, snooze.
    /// (NOT the wake-up check: that one only asks "are you still up?".)
    /// ← USED BY: AlarmSyncService.ringingAlarmID, stopRinging, hasPendingWakeUp
    func ringingSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID>

    /// Only the backup-chain IDs (+30 s … +12 min) of this alarm.
    /// ← USED BY: AlarmSyncService (drops a switched-off alarm's backups unless its mission is pending)
    func backupSystemAlarmIDs(for alarm: WakeAlarm) -> Set<UUID>

    /// Silences every system alarm of this WakeAlarm that is ringing right now
    /// (the app takes over with its own sound on the Ringing screen).
    /// ← USED BY: RingingViewModel.start()
    func stopRinging(_ alarm: WakeAlarm)

    /// Schedules a one-time "snooze" ring `minutes` from now, for alarms without missions.
    /// With the Wake-up guarantee, the backup chain moves behind the snooze ring.
    /// ← USED BY: RingingViewModel.snooze()
    func scheduleSnooze(for alarm: WakeAlarm, minutes: Int) async throws

    /// Pushes the backup chain ahead: its first backup now rings `holdSeconds` (75 s) from now.
    /// ← USED BY: RingingViewModel, every 30 s while the Ringing screen is open and the app is active.
    /// WHY: a ringing system alarm pushes RiseUp into the background. While the user is busy on
    /// our screen, the chain must stay just out of reach; if they leave, it rings within ~a minute.
    func holdBackupChain(for alarm: WakeAlarm) async

    /// Makes sure a guarded alarm has its backup chain for the next ring; schedules it if missing.
    /// ← USED BY: AlarmSyncService (if the user never finished yesterday's mission, the
    ///   chain for the next day was never armed)
    func ensureBackupChain(for alarm: WakeAlarm) async throws

    /// Phase 3, Wake-Up Check (#18): one more alarm `minutes` after the user got up, titled
    /// "Are you up?". If they went back to bed, it wakes them again.
    /// ← USED BY: RingingViewModel.finish()
    func scheduleWakeUpCheck(for alarm: WakeAlarm, minutes: Int) async throws

    /// Stops this alarm's wake-up check if it is ringing right now. Returns true if it was.
    /// ← USED BY: AlarmSyncService (opening RiseUp proves you're awake)
    @discardableResult
    func stopWakeUpCheckIfRinging(for alarm: WakeAlarm) -> Bool

    /// Removes system alarms whose IDs are NOT in `keeping` (leftovers from deleted alarms or bugs).
    /// ← USED BY: AlarmSyncService
    func cancelSystemAlarms(notIn keeping: Set<UUID>)

    /// True when this alarm's wake-up is "in progress": one of its system alarms is ringing
    /// right now, or it already rang and one of its backups is still waiting.
    /// While true the alarm is LOCKED (can't be switched off, edited or deleted), so
    /// nobody can dodge the mission (or, with the Wake-up guarantee, getting up).
    ///
    /// ← USED BY: AlarmListViewModel / AlarmEditorViewModel (the lock), Alarm List banner
    func hasPendingWakeUp(_ alarm: WakeAlarm, now: Date) -> Bool
}

// MARK: - Shared helpers

extension AlarmScheduling {
    /// Makes sure RiseUp may schedule alarms. Shows the system popup the first time;
    /// throws `AlarmPermissionError.denied` if the user says no (now or earlier).
    ///
    /// ← CALLED BY: AlarmListViewModel.setEnabled, AlarmEditorViewModel.save
    ///
    /// LEARN: a protocol *extension* gives every type that adopts the protocol this
    /// method for free. The real scheduler and the mock both get it, written once.
    func requirePermission() async throws {
        if permission == .authorized { return }
        let answer = await requestPermission()   // → the system "Allow alarms?" popup if never asked
        guard answer == .authorized else { throw AlarmPermissionError.denied }
    }

    /// Convenience: `hasPendingWakeUp(alarm, now: .now)`.
    func hasPendingWakeUp(_ alarm: WakeAlarm) -> Bool {
        hasPendingWakeUp(alarm, now: .now)
    }

}
