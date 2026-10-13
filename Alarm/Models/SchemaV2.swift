//
//  SchemaV2.swift
//  RiseUp
//
//  LAYER: Model (SwiftData)
//  WHAT:  Version 2 of the database. FROZEN since 2026-10-13: SchemaV3 is the current shape.
//         Never change this file again: it must keep describing V2 database files exactly.
//         Changes from V1:
//           • WakeAlarm gets `fixedFireDate` (Quick Alarm: ring at an exact moment, e.g. in 10 min)
//           • NEW table `WakeRecord`: one row per wake-up (when it rang, snoozes, mission time)
//  DATA:  WakeAlarm, MissionConfig, WakeRecord.
//
//  CONNECTIONS:
//    ← USED BY:  ModelContainerFactory (current schema), RiseUpMigrationPlan (V1 → V2 stage)
//    ← READ/WRITTEN BY: AlarmRepository (WakeAlarm, MissionConfig), WakeRecordRepository (WakeRecord)
//
//  LEARN: How a schema upgrade works (we're doing it for real now)
//  ───────────────────────────────────────────────────────────────
//  Your iPhone and the Simulator already have databases in the V1 shape. When the new
//  app starts, SwiftData compares the file with RiseUpMigrationPlan:
//     file is V1 → run stage "V1 → V2" → file is now V2 → open it.
//  Our changes are "lightweight": a NEW optional property (nil for old rows) and a NEW
//  table (starts empty). SwiftData does that by itself, so no hand-written code is needed.
//
//  WHY the models are COPIED here (and not just changed in SchemaV1):
//  SchemaV1 must keep describing old files exactly, or SwiftData couldn't recognise them.
//

import Foundation
import SwiftData

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [WakeAlarm.self, MissionConfig.self, WakeRecord.self]
    }

    // MARK: - WakeAlarm

    /// One alarm the user created, e.g. "6:30 AM, Mon–Fri, Math mission".
    @Model
    final class WakeAlarm {
        /// Unique ID, ALSO used as the AlarmKit alarm ID (database row ↔ system alarm).
        @Attribute(.unique) var id: UUID

        /// 0...23 (24-hour clock).
        var hour: Int
        /// 0...59
        var minute: Int

        /// Repeat days as `Weekday` raw values (1 = Sunday … 7 = Saturday). Empty = once.
        var repeatDayNumbers: [Int]

        /// Optional name, e.g. "Gym". Empty string = no label.
        var label: String

        /// Off alarms stay in the list but don't ring.
        var isEnabled: Bool

        /// Sound file name in the app bundle (e.g. "riseup_radar.caf"), or "default".
        var soundName: String

        /// Snooze settings. Mission alarms show "Start Mission" instead of the system Snooze.
        var isSnoozeEnabled: Bool
        var snoozeMinutes: Int
        var maxSnoozeCount: Int

        /// Minutes after dismissal to ask "Are you awake?" (Phase 3). 0 = off.
        var wakeUpCheckMinutes: Int

        var createdAt: Date

        /// NEW in V2. Set for Quick Alarms ("ring in 10 minutes"): the EXACT moment to ring.
        /// `nil` for normal alarms, which ring at hour:minute.
        ///
        /// WHY a separate exact date: hour:minute can't express "in 1 minute" at 4:03:50;
        /// it would ring at 4:04:00, only 10 seconds later.
        var fixedFireDate: Date? = nil

        /// Missions to complete before the alarm can be dismissed.
        /// LEARN: `.cascade` = deleting the alarm deletes its missions too.
        @Relationship(deleteRule: .cascade, inverse: \MissionConfig.alarm)
        var missions: [MissionConfig] = []

        init(
            id: UUID = UUID(),
            hour: Int,
            minute: Int,
            repeatDays: Set<Weekday> = [],
            label: String = "",
            isEnabled: Bool = true,
            soundName: String = "default",
            isSnoozeEnabled: Bool = true,
            snoozeMinutes: Int = 5,
            maxSnoozeCount: Int = 3,
            wakeUpCheckMinutes: Int = 0,
            createdAt: Date = .now,
            fixedFireDate: Date? = nil
        ) {
            self.id = id
            self.hour = hour
            self.minute = minute
            self.repeatDayNumbers = repeatDays.map(\.rawValue).sorted()
            self.label = label
            self.isEnabled = isEnabled
            self.soundName = soundName
            self.isSnoozeEnabled = isSnoozeEnabled
            self.snoozeMinutes = snoozeMinutes
            self.maxSnoozeCount = maxSnoozeCount
            self.wakeUpCheckMinutes = wakeUpCheckMinutes
            self.createdAt = createdAt
            self.fixedFireDate = fixedFireDate
        }
    }

    // MARK: - MissionConfig (unchanged from V1)

    /// The settings for ONE mission attached to an alarm, e.g. "Math, Hard, 3 problems".
    @Model
    final class MissionConfig {
        var id: UUID
        /// `MissionType` raw value ("math", "shake", …).
        var typeRawValue: String
        /// `MissionDifficulty` raw value (0...4).
        var difficultyRawValue: Int
        /// "How many": problems, shakes, phrases…
        var repetitions: Int
        /// Order when an alarm has several missions (0 first).
        var sortOrder: Int
        /// Text some missions need (typing phrase, barcode value).
        var textPayload: String?
        /// Binary data some missions need (photo fingerprint). Stored outside the database file.
        @Attribute(.externalStorage) var dataPayload: Data?
        /// The alarm this mission belongs to.
        var alarm: WakeAlarm?

        init(
            id: UUID = UUID(),
            type: MissionType,
            difficulty: MissionDifficulty = .normal,
            repetitions: Int = 3,
            sortOrder: Int = 0,
            textPayload: String? = nil,
            dataPayload: Data? = nil
        ) {
            self.id = id
            self.typeRawValue = type.rawValue
            self.difficultyRawValue = difficulty.rawValue
            self.repetitions = repetitions
            self.sortOrder = sortOrder
            self.textPayload = textPayload
            self.dataPayload = dataPayload
        }
    }

    // MARK: - WakeRecord (NEW in V2)

    /// One wake-up: written when the ringing screen opens, completed when the user is up.
    ///
    /// ← WRITTEN BY: RingingViewModel (start, snoozes, finish)
    /// ← READ BY:    Morning tab & stats (Phase 5)
    ///
    /// WHY store `alarmTitle` and not a relationship to WakeAlarm: if the user deletes the
    /// alarm later, their wake-up history must stay. A copied title can't disappear.
    @Model
    final class WakeRecord {
        var id: UUID
        /// The WakeAlarm that rang (may no longer exist).
        var alarmID: UUID
        /// The alarm's label at the time ("Gym"), copied for history.
        var alarmTitle: String
        /// When the ringing screen opened.
        var ringStartedAt: Date
        /// When the user was finally up (mission done / dismissed). `nil` = never finished.
        var dismissedAt: Date?
        /// How many times they snoozed before getting up.
        var snoozeCount: Int
        /// How many missions they completed.
        var missionsCompleted: Int
        /// Seconds spent on missions (0 for alarms without missions).
        var missionSeconds: Double
        /// Morning mood check-in (Phase 5). `nil` = not answered.
        var moodRawValue: Int?

        init(
            id: UUID = UUID(),
            alarmID: UUID,
            alarmTitle: String,
            ringStartedAt: Date = .now,
            dismissedAt: Date? = nil,
            snoozeCount: Int = 0,
            missionsCompleted: Int = 0,
            missionSeconds: Double = 0,
            moodRawValue: Int? = nil
        ) {
            self.id = id
            self.alarmID = alarmID
            self.alarmTitle = alarmTitle
            self.ringStartedAt = ringStartedAt
            self.dismissedAt = dismissedAt
            self.snoozeCount = snoozeCount
            self.missionsCompleted = missionsCompleted
            self.missionSeconds = missionSeconds
            self.moodRawValue = moodRawValue
        }
    }
}
