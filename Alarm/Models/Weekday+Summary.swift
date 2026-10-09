//
//  Weekday+Summary.swift
//  RiseUp
//
//  LAYER: Model (pure formatting helper, nothing stored)
//  WHAT:  Turns a set of days into short text: "Once", "Every day", "Weekdays",
//         "Weekends", or "Mon, Wed, Fri".
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: AlarmEditorViewModel.repeatSummary (text under the day chips)
//    ← TODO (your exercise): WakeAlarm.repeatSummary in WakeAlarm+Helpers.swift has the same
//      logic. Make it a one-liner that calls `Weekday.summary(for: repeatDays)`.
//

import Foundation

extension Weekday {
    /// Short description of a set of repeat days.
    ///
    /// LEARN: `static func` on a type = a function that belongs to the TYPE (`Weekday.summary(...)`),
    /// not to one value like `.monday`. Good for helpers that work on many values at once.
    static func summary(for days: Set<Weekday>) -> String {
        // LEARN: `switch` on a Set compares it with each `case` using `==`. First match wins.
        switch days {
        case []:
            return "Once"
        case Set(Weekday.allCases):
            return "Every day"
        case [.monday, .tuesday, .wednesday, .thursday, .friday]:
            return "Weekdays"
        case [.saturday, .sunday]:
            return "Weekends"
        default:
            // Keep the user's calendar order (Mon-first in Pakistan, Sun-first in the US).
            return orderedForCurrentLocale
                .filter { days.contains($0) }
                .map(\.shortName)
                .joined(separator: ", ")
        }
    }
}
