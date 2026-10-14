//
//  Weekday.swift
//  RiseUp
//
//  LAYER: Model (plain value type, NOT stored by itself in SwiftData)
//  WHAT:  The seven days of the week, used for "repeat on Mon, Tue, …".
//  USED BY: WakeAlarm.repeatDays, AlarmScheduleCalculator, AlarmKitScheduler, Alarm Editor (Phase 1).
//

import Foundation

/// A day of the week. Raw values match Apple's `Calendar` (1 = Sunday … 7 = Saturday).
///
/// LEARN: `nonisolated` — this project runs code on the *main actor* (the UI thread)
/// by default. Simple value types like this enum don't touch the UI, so we mark them
/// `nonisolated` and they can be used from ANY thread (background tasks, tests, App Intents).
nonisolated enum Weekday: Int, CaseIterable, Codable, Identifiable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// "Mon", "Tue", … in the user's language.
    var shortName: String {
        Calendar.current.shortWeekdaySymbols[rawValue - 1]
    }

    /// "M", "T", … for compact day chips.
    var veryShortName: String {
        Calendar.current.veryShortWeekdaySymbols[rawValue - 1]
    }

    /// The following day (Saturday → Sunday wraps around).
    ///
    /// WHY: a backup alarm at 23:59 + 2 minutes lands on the NEXT day, so its weekday must shift too.
    var next: Weekday {
        Weekday(rawValue: rawValue % 7 + 1)!        // force unwrap !
    }

    /// The same day as AlarmKit's type (`Locale.Weekday`).
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }

    /// All days in the order the user's region shows them (Monday first in Pakistan
    /// and Europe, Sunday first in the US).
    static var orderedForCurrentLocale: [Weekday] {
        let first = Calendar.current.firstWeekday   // 1 = Sunday, 2 = Monday
        return (0..<7).map { offset in
            Weekday(rawValue: (first - 1 + offset) % 7 + 1)!
        }
    }

    /// The weekday of a given date.
    static func of(_ date: Date, calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date))!
    }
}
