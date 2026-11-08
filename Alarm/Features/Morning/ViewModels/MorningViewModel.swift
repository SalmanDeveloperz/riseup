//
//  MorningViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #23 Morning panel, the Morning tab's root)
//  WHAT:  A friendly morning dashboard: greeting, streak, today's wake-up (with a mood
//         check-in if it's missing), next alarm, this week's wake-up times, a line for the day,
//         and links to Records (#24) and Stats (#25).
//  DATA:  reads WakeRecordRepository.entries + AlarmRepository (next alarm); writes a mood.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeRoot(for: .morning)
//    → READS:      WakeRecordRepository.entries (live list) → WakeStats (pure maths)
//                  AlarmRepository.nextAlarm(after:)
//    → WRITES:     WakeRecordRepository.setMood (Morning check-in #17, if skipped on Success)
//    → NAVIGATES:  AppCoordinator.show(.records / .stats)
//
//  WHY everything takes `now:`: the View passes the current time (refreshed each minute by a
//  TimelineView), so the greeting turns from "Good morning" to "Good afternoon" by itself, and
//  tests can pretend it's any time they like.
//

import Foundation
import Observation

@Observable
final class MorningViewModel {
    private let records: WakeRecordRepository
    private let alarms: AlarmRepository
    private let coordinator: AppCoordinator

    init(records: WakeRecordRepository, alarms: AlarmRepository, coordinator: AppCoordinator) {
        self.records = records
        self.alarms = alarms
        self.coordinator = coordinator
    }

    // MARK: - Values for the View

    /// LEARN: computed from the repository every time, never copied (single source of truth).
    private var entries: [WakeEntry] { records.entries }

    var hasHistory: Bool { !entries.isEmpty }

    /// "Good morning" / "Good afternoon" / "Good evening" / "Still up?"
    func greeting(now: Date) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 4..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Still up?"
        }
    }

    func currentStreak(now: Date) -> Int { WakeStats.currentStreak(entries, now: now) }
    var bestStreak: Int { WakeStats.bestStreak(entries) }

    /// The most recent wake-up that rang today, if any.
    func todayEntry(now: Date) -> WakeEntry? {
        entries.first { Calendar.current.isDate($0.ringStartedAt, inSameDayAs: now) }
    }

    func nextAlarm(now: Date) -> NextAlarmInfo? { alarms.nextAlarm(after: now) }

    /// The last 7 days, for the small chart.
    func weekPoints(now: Date) -> [WakeDayPoint] { WakeStats.dailyPoints(entries, days: 7, now: now) }

    func quote(now: Date) -> String { DailyQuote.forDay(now) }

    /// "6:42 AM", "2 snoozes", "0:38 mission"…
    func summary(of entry: WakeEntry) -> String {
        guard let wokeAt = entry.wokeAt else { return "Rang at \(entry.ringStartedAt.formatted(date: .omitted, time: .shortened)) · not finished" }
        var parts = ["Up at \(wokeAt.formatted(date: .omitted, time: .shortened))"]
        parts.append(entry.snoozeCount == 1 ? "1 snooze" : "\(entry.snoozeCount) snoozes")
        if entry.missionsCompleted > 0 {
            parts.append("mission \(SuccessView.durationText(entry.missionSeconds))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    /// Morning check-in (#17) from the Morning tab, for users who skipped it on Success.
    func setMood(_ mood: Mood, for entry: WakeEntry) {
        try? records.setMood(mood, forRecordID: entry.id)   // → entries refresh → View redraws
    }

    func open(_ route: MorningRoute) {
        coordinator.show(route)                             // → morningPath.append → pushed screen
    }
}
