//
//  RiseUpAlarmMetadata.swift
//  RiseUp
//
//  LAYER: Shared (compiled into BOTH the app and the RiseUpWidgets extension)
//  WHAT:  Extra info we attach to every system alarm.
//  DATA:  travels inside AlarmKit's `AlarmAttributes`; iOS stores it, not SwiftData.
//
//  CONNECTIONS:
//    ← CREATED BY: AlarmKitScheduler.makeAttributes (and the debug Alarm Lab)
//    → READ BY:    RiseUpWidgets/AlarmLiveActivity (lock screen + Dynamic Island)
//
//  WHY a separate /Shared folder: the app and the widget extension are two different
//  programs. iOS hands the widget the alarm's attributes, and the widget must decode
//  them with the EXACT same type. Files in /Shared belong to both targets, so there is
//  only one copy of this struct and the two sides can never disagree.
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
