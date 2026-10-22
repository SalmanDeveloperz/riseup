//
//  StatsViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #25 Stats)
//  WHAT:  Numbers and charts for the last 7 or 30 days: average wake-up time, how often you
//         got up without giving up, snoozes, mission time, mood.
//  DATA:  reads WakeRecordRepository.entries (live values) → WakeStats (pure maths).
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: MorningRoute.stats)
//    ← OPENED BY:  MorningViewModel.open(.stats) → AppCoordinator.show → morningPath
//    → READS:      WakeRecordRepository.entries, WakeStats
//

import Foundation
import Observation

@Observable
final class StatsViewModel {

    enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        var id: Int { rawValue }
        var title: String { self == .week ? "7 days" : "30 days" }
    }

    /// Bound to the segmented picker.
    var range: Range = .week

    private let records: WakeRecordRepository

    init(records: WakeRecordRepository) {
        self.records = records
    }

    // MARK: - Values for the View

    var hasHistory: Bool { !records.entries.isEmpty }

    func points(now: Date) -> [WakeDayPoint] {
        WakeStats.dailyPoints(records.entries, days: range.rawValue, now: now)
    }

    /// Entries that rang inside the chosen range.
    func entriesInRange(now: Date) -> [WakeEntry] {
        guard let start = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1),
                                                to: Calendar.current.startOfDay(for: now)) else { return [] }
        return records.entries.filter { $0.ringStartedAt >= start }
    }

    /// "6:48 AM" or "—"
    func averageWakeText(now: Date) -> String {
        guard let minutes = WakeStats.averageWakeMinute(points(now: now)),
              let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now)
        else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "92%" or "—"
    func successText(now: Date) -> String {
        guard let rate = WakeStats.successRate(entriesInRange(now: now)) else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }

    func totalSnoozes(now: Date) -> Int {
        entriesInRange(now: now).reduce(0) { $0 + $1.snoozeCount }
    }

    /// "0:42" or "—"
    func averageMissionText(now: Date) -> String {
        guard let seconds = WakeStats.averageMissionSeconds(entriesInRange(now: now)) else { return "—" }
        return SuccessView.durationText(seconds)
    }

    #if DEBUG
    /// Debug builds only: fills 45 days of sample history so the charts can be tried.
    func addSampleData() {
        try? records.addSampleHistory(days: 45)
    }
    #endif
}
