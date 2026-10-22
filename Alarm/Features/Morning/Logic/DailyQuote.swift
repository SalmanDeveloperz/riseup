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
        "Every morning is another chance to get it right.",
        "The life you dream of starts with what you do today.",
        "Wake up with hope. Go to sleep with progress.",
        "You don't need a perfect day to make real progress.",
        "A little courage this morning can change your whole day.",
        "Your future is built by the choices you make today.",
        "Leave yesterday behind. Today deserves a fresh start.",
        "The hardest step is getting started. Take it anyway.",
        "Make today a day your future self will thank you for.",
        "You have another chance to become who you want to be.",
        "Great things begin when you stop waiting and start trying.",
        "You don't have to change everything. Just start somewhere.",
        "Let this morning be the beginning of something better.",
        "Every small effort today brings you closer to your dreams.",
        "Some of your best days begin when you least expect them.",
        "Wake up knowing that your story is still being written.",
        "The way you begin today can shape how you live it.",
        "Don't let yesterday decide what tomorrow can become.",
        "Be patient with your journey, but never stop moving forward.",
        "One day, these little efforts will mean everything.",
        "You were made for more than putting your dreams on hold.",
        "Start your morning with gratitude and your day with purpose.",
        "You don't need all the answers to take the next step.",
        "Give yourself a chance to surprise yourself today.",
        "A fresh morning brings possibilities you haven't met yet.",
        "Build a life you don't constantly need a break from.",
        "Show up for yourself, even when no one else is watching.",
        "The smallest beginning can lead to the biggest change.",
        "Today may not be easy, but it can still be meaningful.",
        "Get up and give the day a reason to be remembered."
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
