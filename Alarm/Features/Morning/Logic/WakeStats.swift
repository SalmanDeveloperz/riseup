//
//  WakeStats.swift
//  RiseUp
//
//  LAYER: Logic (pure functions + a value snapshot, no UI, no database)
//  WHAT:  Everything the Morning tab, Records calendar and Stats screen calculate from
//         the wake-up history: streaks, per-day summaries, averages.
//  DATA:  works on `WakeEntry` values (copies of WakeRecord rows).
//
//  CONNECTIONS:
//    ← USED BY: MorningViewModel, RecordsViewModel, StatsViewModel, RiseUpTests (WakeStatsTests)
//    ← WakeEntry CREATED BY: WakeEntry.init(_ record:) (bottom of this file)
//
//  WHY pure functions: "is the streak 3 or 4 days?" is exactly the kind of question that's
//  easy to get wrong around midnight. Pure functions with a fixed `now` and calendar can be
//  tested for every tricky case without waiting for real mornings.
//

import Foundation

/// One wake-up, as a plain value (Views never get the SwiftData object; see AlarmRow's WHY).
nonisolated struct WakeEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let alarmTitle: String
    /// When the alarm started ringing (the Ringing screen opened).
    let ringStartedAt: Date
    /// When the user was up. `nil` = never finished (gave up, closed the app…).
    let wokeAt: Date?
    let snoozeCount: Int
    let missionsCompleted: Int
    let missionSeconds: Double
    let mood: Mood?

    var isFinished: Bool { wokeAt != nil }

    /// "Clean" wake-up: finished without snoozing. Shown brighter in the calendar.
    var isClean: Bool { isFinished && snoozeCount == 0 }
}

/// One day on a chart.
nonisolated struct WakeDayPoint: Identifiable, Equatable, Sendable {
    /// Midnight at the start of the day.
    let day: Date
    /// Minutes after midnight when the user was up (first finished wake-up), or `nil`.
    let wakeMinuteOfDay: Int?
    let snoozes: Int
    let missionSeconds: Double
    let mood: Mood?
    var id: Date { day }
}

nonisolated enum WakeStats {

    /// Days in a row (ending today, or yesterday if today has no wake-up YET) with at
    /// least one finished wake-up.
    ///
    /// WHY "or yesterday": at 5 a.m., before your alarm, your streak isn't broken yet.
    static func currentStreak(_ entries: [WakeEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = finishedDays(entries, calendar: calendar)
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// The longest run of consecutive days ever.
    static func bestStreak(_ entries: [WakeEntry], calendar: Calendar = .current) -> Int {
        let days = finishedDays(entries, calendar: calendar).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), next == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Entries grouped by the day they rang (midnight → entries, oldest first).
    static func byDay(_ entries: [WakeEntry], calendar: Calendar = .current) -> [Date: [WakeEntry]] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.ringStartedAt) }
            .mapValues { $0.sorted { $0.ringStartedAt < $1.ringStartedAt } }
    }

    /// One point per day for the last `days` days (oldest first), including empty days.
    static func dailyPoints(_ entries: [WakeEntry], days: Int, now: Date = .now, calendar: Calendar = .current) -> [WakeDayPoint] {
        let grouped = byDay(entries, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        return (0..<max(days, 0)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEntries = grouped[day] ?? []
            let firstUp = dayEntries.compactMap(\.wokeAt).min()
            return WakeDayPoint(
                day: day,
                wakeMinuteOfDay: firstUp.map { minuteOfDay($0, calendar: calendar) },
                snoozes: dayEntries.reduce(0) { $0 + $1.snoozeCount },
                missionSeconds: dayEntries.reduce(0) { $0 + $1.missionSeconds },
                mood: dayEntries.last(where: { $0.mood != nil })?.mood
            )
        }
    }

    /// Average "up at" time, in minutes after midnight. `nil` without finished wake-ups.
    ///
    /// WHY not a plain average (found in code review): times wrap around midnight. 23:50 and 00:10
    /// are 20 minutes apart, but (1430 + 10) / 2 = 12:00 noon! So each time is treated as a point on
    /// a clock face, the points are averaged, and the hand's angle is read back. Normal mornings
    /// give exactly the same answer as a plain average.
    static func averageWakeMinute(_ points: [WakeDayPoint]) -> Int? {
        let minutes = points.compactMap(\.wakeMinuteOfDay)
        guard !minutes.isEmpty else { return nil }
        let day = 24.0 * 60
        // LEARN: cos/sin turn a time into an (x, y) point on a circle; atan2 turns (x, y) back into an angle.
        let angles = minutes.map { Double($0) / day * 2 * .pi }
        let x = angles.map(cos).reduce(0, +)
        let y = angles.map(sin).reduce(0, +)
        guard abs(x) > 1e-9 || abs(y) > 1e-9 else {                // exactly opposite times: no "middle"
            return minutes.reduce(0, +) / minutes.count
        }
        var angle = atan2(y, x)
        if angle < 0 { angle += 2 * .pi }
        return Int((angle / (2 * .pi) * day).rounded()) % Int(day)
    }

    /// Finished wake-ups ÷ all wake-ups (0…1). `nil` without any.
    static func successRate(_ entries: [WakeEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return Double(entries.filter(\.isFinished).count) / Double(entries.count)
    }

    /// Average mission time of finished wake-ups that had missions.
    static func averageMissionSeconds(_ entries: [WakeEntry]) -> Double? {
        let times = entries.filter { $0.isFinished && $0.missionsCompleted > 0 }.map(\.missionSeconds)
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }

    /// 6:30 → 390.
    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func finishedDays(_ entries: [WakeEntry], calendar: Calendar) -> Set<Date> {
        Set(entries.filter(\.isFinished).map { calendar.startOfDay(for: $0.ringStartedAt) })
    }
}

// MARK: - WakeRecord → WakeEntry

// LEARN: not `nonisolated`: it reads a SwiftData @Model, which lives on the main actor.
extension WakeEntry {
    init(_ record: WakeRecord) {
        self.init(
            id: record.id,
            alarmTitle: record.alarmTitle,
            ringStartedAt: record.ringStartedAt,
            wokeAt: record.dismissedAt,
            snoozeCount: record.snoozeCount,
            missionsCompleted: record.missionsCompleted,
            missionSeconds: record.missionSeconds,
            mood: record.moodRawValue.flatMap(Mood.init(rawValue:))
        )
    }
}
