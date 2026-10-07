//
//  WakeAlarm+Helpers.swift
//  RiseUp
//
//  LAYER: Model (computed helpers, nothing here is stored)
//  WHAT:  Friendly, typed accessors on top of the raw stored properties.
//  USED BY: ViewModels and services.
//
//  LEARN: Properties declared in an `extension` of a @Model class are NOT saved
//  in the database. Extensions can't add stored properties, only computed ones.
//  That makes them perfect for "convenience" logic.
//

import Foundation

extension WakeAlarm {
    /// Repeat days as typed `Weekday` values. Reading and writing both work.
    var repeatDays: Set<Weekday> {
        get { Set(repeatDayNumbers.compactMap(Weekday.init(rawValue:))) }
        set { repeatDayNumbers = newValue.map(\.rawValue).sorted() }
    }

    /// True when the alarm rings on specific weekdays; false = one-time alarm.
    var isRepeating: Bool { !repeatDayNumbers.isEmpty }

    /// True when at least one mission must be completed to dismiss the alarm.
    var hasMissions: Bool { !missions.isEmpty }

    /// Missions in the order they should run.
    var sortedMissions: [MissionConfig] {
        missions.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The label, or a friendly fallback when it's empty.
    var displayTitle: String {
        label.isEmpty ? "Alarm" : label
    }
}

extension MissionConfig {
    /// Typed mission kind. Falls back to `.math` if the stored text is unknown
    /// (e.g. data from a newer app version).
    var type: MissionType {
        get { MissionType(rawValue: typeRawValue) ?? .math }
        set { typeRawValue = newValue.rawValue }
    }

    /// Typed difficulty.
    var difficulty: MissionDifficulty {
        get { MissionDifficulty(rawValue: difficultyRawValue) ?? .normal }
        set { difficultyRawValue = newValue.rawValue }
    }
}
