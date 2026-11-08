//
//  SchemaV4.swift
//  RiseUp
//
//  LAYER: Model (SwiftData)
//  WHAT:  Version 4 of the database: the CURRENT shape.
//         Change from V3 (2026-10-18):
//           • WakeAlarm gets `extraOnceDate`: "Once + days" (ring one extra time, e.g. today at 12:00,
//             on top of the repeat days, e.g. every Wednesday)
//  DATA:  WakeAlarm, MissionConfig, WakeRecord.
//
//  CONNECTIONS:
//    ← USED BY:  ModelContainerFactory (current schema), RiseUpMigrationPlan (V3 → V4 stage)
//    ← READ/WRITTEN BY: AlarmRepository (WakeAlarm, MissionConfig), WakeRecordRepository (WakeRecord)
//
//  LEARN: the same 4 steps as V1 → V2 (see RiseUpMigrationPlan): copy the newest schema, make the
//  change here, add a migration stage, move the typealiases to the bottom of THIS file.
//  A new optional property is "lightweight": existing alarms simply get `nil` (= no extra ring).
//

import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

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

        /// NEW in V3. The wallpaper behind the Ringing screen, as `Wallpaper.rawValue`
        /// ("live.aurora", "photo.<uuid>", "surprise"). `nil` = use the default from Settings.
        var wallpaperID: String? = nil

        /// NEW in V4. "Once + days": the EXACT moment of one extra ring on top of the repeat days
        /// (e.g. today 12:00 when the alarm repeats every Wednesday at 12:00). `nil` = no extra ring.
        ///
        /// WHY a date and not a Bool: "once" means one specific moment. A date says WHICH one, so the app
        /// can tell "still to come" from "already rang" (then it's ignored and cleared), and the weekly
        /// rings keep going. Only used with repeat days; a one-time alarm is already "once".
        /// → WakeAlarm+Schedule.swift (`upcomingOnceRing`, `nextFireDate`)
        var extraOnceDate: Date? = nil

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
            fixedFireDate: Date? = nil,
            wallpaperID: String? = nil,
            extraOnceDate: Date? = nil
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
            self.wallpaperID = wallpaperID
            self.extraOnceDate = extraOnceDate
        }
    }

    // MARK: - MissionConfig (unchanged since V1)

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

    // MARK: - WakeRecord (unchanged since V2)

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

// MARK: - Current model names

// LEARN: the rest of the app writes `WakeAlarm`, never `SchemaV4.WakeAlarm`. When a
// SchemaV5 arrives, only these lines change.
typealias WakeAlarm = SchemaV4.WakeAlarm
typealias MissionConfig = SchemaV4.MissionConfig
typealias WakeRecord = SchemaV4.WakeRecord
