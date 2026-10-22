//
//  SchemaV1.swift
//  RiseUp
//
//  LAYER: Model (SwiftData)
//  WHAT:  Version 1 of the database: the `WakeAlarm` and `MissionConfig` tables.
//         FROZEN since SchemaV2 (2026-10-09). The app now uses SchemaV2; this file only
//         describes old databases so RiseUpMigrationPlan can upgrade them.
//  USED BY: RiseUpMigrationPlan (as the "from" version).
//
//  LEARN: SwiftData basics
//  ──────────────────────
//  • `@Model` turns a normal Swift class into a database table. Every stored
//    property becomes a column, and SwiftData saves/loads it for us.
//  • Objects live in a `ModelContext` (think "scratchpad"). Changes are written to disk
//    when the context is saved.
//  • A `ModelContainer` owns the actual database file on the device.
//
//  WHY a "VersionedSchema"?
//  Once RiseUp is on the App Store, people's phones contain a database in THIS
//  shape. If we later add/rename/remove a property, SwiftData must know how to
//  upgrade old data ("migration"). Putting the models inside `SchemaV1` from day 1
//  means a future change is easy: we copy them into `SchemaV2`, edit them, and add a
//  migration stage in RiseUpMigrationPlan.swift.
//

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    // LEARN: `static let` (not `var`) because Swift 6 forbids shared mutable globals,
    // which could be changed from two threads at once.
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [WakeAlarm.self, MissionConfig.self]
    }

    // MARK: - WakeAlarm

    /// One alarm the user created, e.g. "6:30 AM, Mon–Fri, Math mission".
    ///
    /// WHY the name `WakeAlarm` and not `Alarm`? Apple's AlarmKit already has a type
    /// called `Alarm`. Two types with the same name in one file would confuse both
    /// the compiler and us.
    @Model
    final class WakeAlarm {
        /// Unique ID. We ALSO use it as the AlarmKit alarm ID, so the system alarm
        /// and our database row are linked by the same UUID.
        @Attribute(.unique) var id: UUID

        /// 0...23 (24-hour clock, even if the user sees "PM").
        var hour: Int
        /// 0...59
        var minute: Int

        /// Days this alarm repeats, as `Weekday` raw values (1 = Sunday … 7 = Saturday).
        /// Empty = rings once.
        ///
        /// WHY `[Int]` instead of `Set<Weekday>`? Simple types are the safest thing to
        /// store in a database. The `repeatDays` property in the extension below converts
        /// these numbers to and from nice `Weekday` values.
        var repeatDayNumbers: [Int]

        /// Optional name, e.g. "Gym". Empty string = no label.
        var label: String

        /// Off alarms stay in the list but don't ring.
        var isEnabled: Bool

        /// Sound file name in the app bundle (e.g. "spike_beep.caf"), or "default" for the system sound.
        var soundName: String

        /// Snooze settings. Ignored when the alarm has missions (missions replace snoozing on the lock screen).
        var isSnoozeEnabled: Bool
        var snoozeMinutes: Int
        var maxSnoozeCount: Int

        /// Minutes after dismissal to ask "Are you awake?" (Phase 3). 0 = off.
        var wakeUpCheckMinutes: Int

        var createdAt: Date

        /// Missions the user must complete to turn this alarm off.
        ///
        /// LEARN: `@Relationship(deleteRule: .cascade)` means: delete the alarm →
        /// SwiftData also deletes its missions automatically. `inverse:` connects this
        /// list to `MissionConfig.alarm`, so both sides stay in sync.
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
            createdAt: Date = .now
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
        }
    }

    // MARK: - MissionConfig

    /// The settings for ONE mission attached to an alarm, e.g. "Math, Hard, 3 problems".
    @Model
    final class MissionConfig {
        var id: UUID

        /// `MissionType` raw value ("math", "shake", …).
        /// WHY stored as String? SwiftData predicates (database queries) work reliably on
        /// simple types. Use the `type` property in the extension below; it's typed and safe.
        var typeRawValue: String

        /// `MissionDifficulty` raw value (0...4).
        var difficultyRawValue: Int

        /// "How many": problems to solve, shakes, steps, squats, phrases…
        var repetitions: Int

        /// Order in which missions run when an alarm has several (0 first).
        var sortOrder: Int

        /// Text data some missions need: the typing phrase, or the registered barcode value.
        var textPayload: String?

        /// Binary data some missions need, e.g. the photo mission's image "fingerprint".
        ///
        /// LEARN: `.externalStorage` lets SwiftData save big blobs as separate files
        /// instead of inside the database, which keeps queries fast.
        @Attribute(.externalStorage) var dataPayload: Data?

        /// The alarm this mission belongs to (the other side of `WakeAlarm.missions`).
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
}

// The short names `WakeAlarm` / `MissionConfig` now point at the newest schema (see SchemaV3.swift).
// WHY keep this file at all: SwiftData needs the OLD shape to recognise and upgrade
// databases created by older app versions. Never edit SchemaV1 again: it's frozen history.
