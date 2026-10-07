//
//  RiseUpAlarmMetadata.swift
//  RiseUp
//
//  LAYER: Service (AlarmKit support type)
//  WHAT:  Extra info we attach to every system alarm.
//  USED BY: AlarmKitScheduler; in Phase 1 also the widget extension (Live Activity UI).
//

import AlarmKit
import Foundation

/// Data travelling with each AlarmKit alarm.
///
/// LEARN: AlarmKit's `AlarmAttributes` is generic over "metadata": any small
/// Codable struct we choose. The system stores it and hands it back to our widget
/// extension when it draws the alarm on the lock screen / Dynamic Island.
nonisolated struct RiseUpAlarmMetadata: AlarmMetadata {
    /// The `WakeAlarm.id` this system alarm belongs to.
    var wakeAlarmID: UUID
    /// True for backup-chain alarms ("Mission not finished!"), false for the main alarm.
    var isBackup: Bool
}
