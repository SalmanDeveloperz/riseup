//
//  AlarmKitScheduler.swift
//  RiseUp
//
//  LAYER: Service (real implementation of AlarmScheduling)
//  WHAT:  Turns a `WakeAlarm` from our database into real system alarms using Apple's AlarmKit.
//  USED BY: AppDependencies.live() → every ViewModel that schedules alarms.
//  DATA:  reads WakeAlarm (never saves it; saving is the repository's job).
//
//  HOW RISEUP ALARMS WORK (read this first!)
//  ──────────────────────────────────────────
//  1. MAIN ALARM: one AlarmKit alarm with the SAME id as the WakeAlarm. It repeats
//     on the chosen weekdays and rings even in Silent mode or when the app is closed.
//
//  2. BACKUP CHAIN (only for alarms with missions):
//     WHY: iOS always shows a "Stop" button on a ringing alarm, and we can't hide it.
//     A sleepy user could press Stop and skip the mission. So we also schedule a few
//     one-time "backup" alarms a few minutes after the main one (e.g. +1, +2, +3, +5, +8 min).
//     • User completes the mission → `missionCompleted` cancels the backups. Silence.
//     • User just presses Stop → backups keep ringing until they do the mission.
//     Backups use FIXED dates (just the next occurrence), so after each wake-up we
//     re-arm them for the following day.
//
//  3. Backup IDs are calculated from the alarm ID (see `backupID`), so we never need
//     to store them in the database. We can always work out which ones to cancel.
//

import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

final class AlarmKitScheduler: AlarmScheduling {

    /// Minutes after the main alarm when backup alarms ring.
    /// TRY: change to `[1, 2, 3]` for a shorter chain while testing.
    static let backupOffsetsInMinutes = [1, 2, 3, 5, 8]

    // WHY we always write `AlarmManager.shared.…` instead of keeping it in a property:
    // AlarmKit's async methods run on a background thread, and `AlarmManager` isn't
    // marked thread-safe (`Sendable`). If we stored it in a property of this main-thread
    // class, Swift 6 would refuse to "send" it to that background method (data-race
    // protection). Reading `AlarmManager.shared` fresh at each call avoids that.

    // MARK: - Permission

    var permission: AlarmPermission {
        Self.map(AlarmManager.shared.authorizationState)
    }

    func requestPermission() async -> AlarmPermission {
        do {
            return Self.map(try await AlarmManager.shared.requestAuthorization())
        } catch {
            // WHY: the request only throws for unexpected system errors. Treat that as "not allowed".
            return .denied
        }
    }

    // MARK: - Scheduling

    func schedule(_ alarm: WakeAlarm) async throws {
        // Start clean: remove any older version of this alarm (main + backups).
        cancel(alarm)
        guard alarm.isEnabled else { return }

        try await scheduleMainAlarm(for: alarm)

        if alarm.hasMissions {
            try await scheduleBackupChain(for: alarm, afterDate: .now)
        }
    }

    func cancel(_ alarm: WakeAlarm) {
        // WHY `try?`: `cancel` throws if the alarm isn't scheduled (already fired, never
        // scheduled…). That's fine for us; the goal "make sure it's gone" is reached either way.
        try? AlarmManager.shared.cancel(id: alarm.id)
        cancelBackupChain(for: alarm)
    }

    func missionCompleted(for alarm: WakeAlarm) async throws {
        cancelBackupChain(for: alarm)

        // Repeating alarms need tomorrow's (or next week's) chain armed right away.
        // One-time alarms are finished; their ViewModel turns them off.
        if alarm.isRepeating && alarm.isEnabled && alarm.hasMissions {
            try await scheduleBackupChain(for: alarm, afterDate: .now)
        }
    }

    func scheduledSystemAlarmIDs() -> Set<UUID> {
        // LEARN: `(try? x) ?? []` means "try to read x; if it throws, use an empty list".
        Set(((try? AlarmManager.shared.alarms) ?? []).map(\.id))
    }

    // MARK: - Main alarm

    private func scheduleMainAlarm(for alarm: WakeAlarm) async throws {
        // LEARN: `.relative` = "at this clock time" (follows time-zone changes), with
        // optional weekly repetition. `.fixed` = one exact moment (used for backups).
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.isRepeating
            ? .weekly(alarm.repeatDays.map(\.localeWeekday))
            : .never
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: recurrence
        ))

        // Snooze only exists for alarms WITHOUT missions. Mission alarms get "Start Mission" instead.
        let usesSnooze = !alarm.hasMissions && alarm.isSnoozeEnabled
        let countdown = usesSnooze
            ? Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeMinutes * 60))
            : nil

        let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: makeAttributes(for: alarm, isBackup: false, usesSnooze: usesSnooze),
            secondaryIntent: alarm.hasMissions
                ? StartMissionIntent(wakeAlarmID: alarm.id, ringingSystemAlarmID: alarm.id)
                : nil,
            sound: Self.sound(named: alarm.soundName)
        )
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
    }

    // MARK: - Backup chain

    private func scheduleBackupChain(for alarm: WakeAlarm, afterDate: Date) async throws {
        guard let mainDate = AlarmScheduleCalculator.nextOccurrence(
            hour: alarm.hour,
            minute: alarm.minute,
            weekdays: alarm.repeatDays,
            after: afterDate
        ) else { return }

        let dates = AlarmScheduleCalculator.backupDates(
            after: mainDate,
            offsetsInMinutes: Self.backupOffsetsInMinutes
        )

        // LEARN: `enumerated()` gives us (index, element) pairs: 0, 1, 2…
        for (index, date) in dates.enumerated() {
            let backupID = Self.backupID(for: alarm.id, index: index)
            let configuration = AlarmManager.AlarmConfiguration<RiseUpAlarmMetadata>(
                schedule: .fixed(date),
                attributes: makeAttributes(for: alarm, isBackup: true, usesSnooze: false),
                secondaryIntent: StartMissionIntent(wakeAlarmID: alarm.id, ringingSystemAlarmID: backupID),
                sound: Self.sound(named: alarm.soundName)
            )
            _ = try await AlarmManager.shared.schedule(id: backupID, configuration: configuration)
        }
    }

    private func cancelBackupChain(for alarm: WakeAlarm) {
        for index in Self.backupOffsetsInMinutes.indices {
            try? AlarmManager.shared.cancel(id: Self.backupID(for: alarm.id, index: index))
        }
    }

    /// Calculates the ID of backup alarm number `index` for a given alarm.
    ///
    /// WHY: we derive backup IDs from the alarm's own ID (changing its last two bytes)
    /// instead of storing random ones. Any time later, even after an app restart, we
    /// can recompute exactly which system alarms to cancel. Collisions with other random
    /// UUIDs are practically impossible (2¹²² possibilities).
    static func backupID(for alarmID: UUID, index: Int) -> UUID {
        // LEARN: `UUID.uuid` exposes the 16 raw bytes as a tuple (.0 … .15).
        var bytes = alarmID.uuid
        bytes.14 ^= 0xB0                       // "B" for backup: marks the family
        bytes.15 = bytes.15 &+ UInt8(index + 1) // &+ wraps around instead of crashing on overflow
        return UUID(uuid: bytes)
    }

    // MARK: - Presentation (what the system shows)

    private func makeAttributes(for alarm: WakeAlarm, isBackup: Bool, usesSnooze: Bool) -> AlarmAttributes<RiseUpAlarmMetadata> {
        let title: LocalizedStringResource = isBackup
            ? "Mission not finished!"
            : LocalizedStringResource(stringLiteral: alarm.displayTitle)

        // The second button: "Start Mission" (opens the app), "Snooze" (system countdown), or none.
        let secondaryButton: AlarmButton?
        let secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        if alarm.hasMissions {
            secondaryButton = AlarmButton(text: "Start Mission", textColor: .white, systemImageName: "bolt.fill")
            secondaryBehavior = .custom      // runs our StartMissionIntent
        } else if usesSnooze {
            secondaryButton = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
            secondaryBehavior = .countdown   // AlarmKit counts down `postAlert` seconds, then rings again
        } else {
            secondaryButton = nil
            secondaryBehavior = nil
        }

        // WHY the `stopButton:` version: our minimum is iOS 26.0, where this initializer is
        // required. iOS 26.1+ ignores the stop button style and always shows its own.
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryBehavior
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: usesSnooze ? AlarmPresentation.Countdown(title: "Snoozing") : nil
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: RiseUpAlarmMetadata(wakeAlarmID: alarm.id, isBackup: isBackup),
            tintColor: Theme.Colors.neonPink
        )
    }

    // MARK: - Helpers

    /// "default" → the system alarm sound; anything else → a sound file in the app bundle.
    static func sound(named name: String) -> AlertConfiguration.AlertSound {
        name == "default" ? .default : .named(name)
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> AlarmPermission {
        switch state {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}
