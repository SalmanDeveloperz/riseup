//
//  DailyQuote.swift
//  RiseUp
//
//  LAYER: Logic (pure, no UI)
//  WHAT:  One short morning line per day, the same all day long, a new one tomorrow.
//  DATA:  a fixed list in this file (no network).
//
//  CONNECTIONS:
//    ← USED BY: MorningViewModel, RiseUpTests
//
//  WHY our own lines: famous quotes can be copyrighted or misattributed. These are
//  written for RiseUp, so they're safe to ship.
//  TRY: add your own line at the end of `all`. It joins the rotation automatically.
//

import Foundation

nonisolated enum DailyQuote {
    static let all: [String] = [
        "You already did the hardest part: getting up.",
        "Small mornings build big days.",
        "Be the person your alarm believes in.",
        "One good morning is a start. Seven is a habit.",
        "The snooze button never changed anyone's life.",
        "Today is a blank page. Write something good.",
        "Your future self says thank you for getting up.",
        "Energy follows action. Move first, feel later.",
        "Win the morning, and the day follows.",
        "Discipline is remembering what you want.",
        "Progress, not perfection.",
        "Fresh day, fresh chances.",
        "The early hours are yours alone. Use them.",
        "Done is better than perfect. Start.",
        "Every streak starts with day one.",
        "Drink some water. Open the curtains. Go.",
        "You don't need motivation. You need a first step.",
        "Today's effort is tomorrow's ease.",
        "Rise up. Show up. Keep going.",
        "Make your bed, make your day.",
    ]

    /// The line for `date`'s day. Same input → same line (no randomness), so it doesn't
    /// change every time the Morning tab is opened.
    static func forDay(_ date: Date, calendar: Calendar = .current) -> String {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        // Mixing in the year means 1 January doesn't show the same line every year.
        let index = (dayOfYear + year * 7) % all.count
        return all[index]
    }
}
