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

/// Schedules and cancels RiseUp alarms with the operating system.
protocol AlarmScheduling: AnyObject {
    /// Current permission state (no popup).
    var permission: AlarmPermission { get }

    /// Shows the system "Allow alarms?" popup the first time; afterwards returns the saved answer.
    func requestPermission() async -> AlarmPermission

    /// Schedules (or re-schedules) an alarm. Replaces anything previously scheduled for it.
    /// Disabled alarms are just cancelled.
    func schedule(_ alarm: WakeAlarm) async throws

    /// Removes the alarm and its backup chain from the system.
    func cancel(_ alarm: WakeAlarm)

    /// Called when the user finishes the alarm's missions: stops the backup chain and,
    /// for repeating alarms, arms a fresh chain for the next occurrence.
    func missionCompleted(for alarm: WakeAlarm) async throws

    /// IDs of every alarm currently scheduled with the system (main + backups). For debugging.
    func scheduledSystemAlarmIDs() -> Set<UUID>
}
