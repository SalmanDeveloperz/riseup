//
//  RecordsViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #24 Records calendar)
//  WHAT:  A month calendar of wake-ups. Each day is coloured by how it went (clean / snoozed /
//         missed). Tap a day to see its wake-ups. Arrows move between months.
//  DATA:  reads WakeRecordRepository.entries (live values). Writes nothing (except Debug sample data).
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: MorningRoute.records)
//    ← OPENED BY:  MorningViewModel.open(.records) → AppCoordinator.show → morningPath
//    → READS:      WakeRecordRepository.entries → WakeStats.byDay
//
//  LEARN: building a month grid
//  ────────────────────────────
//  A calendar is a 7-column grid. Before day 1 we add empty cells so day 1 lands under the
//  right weekday ("leading blanks"). Which weekday comes first depends on the country:
//  Monday in Pakistan, Sunday in the US. `Calendar.current.firstWeekday` tells us.
//

import Foundation
import Observation

@Observable
final class RecordsViewModel {

    /// How a day went, for its colour.
    enum DayStatus {
        case none        // no alarm rang
        case clean       // up without snoozing
        case snoozed     // up, but snoozed first
        case missed      // rang, never finished
    }

    /// One cell of the grid. `date == nil` = an empty cell before day 1.
    struct DayCell: Identifiable {
        let id: Int
        let date: Date?
        let dayNumber: Int
        let status: DayStatus
        let isToday: Bool
    }

    // MARK: - State

    /// The first day of the month on screen.
    private(set) var month: Date
    /// The tapped day (midnight), or nil.
    private(set) var selectedDay: Date?

    private let records: WakeRecordRepository
    private let calendar: Calendar

    init(records: WakeRecordRepository, now: Date = .now, calendar: Calendar = .current) {
        self.records = records
        self.calendar = calendar
        self.month = calendar.dateInterval(of: .month, for: now)?.start ?? now
        self.selectedDay = calendar.startOfDay(for: now)
    }

    // MARK: - Values for the View

    private var byDay: [Date: [WakeEntry]] { WakeStats.byDay(records.entries, calendar: calendar) }

    var hasHistory: Bool { !records.entries.isEmpty }

    /// "October 2026"
    var monthTitle: String { month.formatted(.dateTime.month(.wide).year()) }

    /// "M T W T F S S" in the user's week order.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols      // always Sunday first
        let start = calendar.firstWeekday - 1                         // 0 = Sunday, 1 = Monday…
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Blanks + one cell per day of the month.
    func cells(now: Date = .now) -> [DayCell] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let blanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let grouped = byDay
        let today = calendar.startOfDay(for: now)

        var cells = (0..<blanks).map { DayCell(id: -1 - $0, date: nil, dayNumber: 0, status: .none, isToday: false) }
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: month) else { continue }
            cells.append(DayCell(id: day, date: date, dayNumber: day,
                                 status: Self.status(of: grouped[date] ?? []), isToday: date == today))
        }
        return cells
    }

    /// Wake-ups of the selected day, oldest first.
    var selectedEntries: [WakeEntry] {
        guard let selectedDay else { return [] }
        return byDay[selectedDay] ?? []
    }

    /// "16 wake-ups · 12 without snoozing" for the month on screen.
    var monthSummary: String {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return "" }
        let inMonth = records.entries.filter { interval.contains($0.ringStartedAt) }
        guard !inMonth.isEmpty else { return "No wake-ups this month yet" }
        let clean = inMonth.filter(\.isClean).count
        return "\(inMonth.count) wake-ups · \(clean) without snoozing"
    }

    /// No browsing into the future: there's nothing there yet.
    func canGoForward(now: Date = .now) -> Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return false }
        return next <= now
    }

    // MARK: - Actions

    func showPreviousMonth() {
        if let previous = calendar.date(byAdding: .month, value: -1, to: month) { show(month: previous) }
    }

    func showNextMonth() {
        guard canGoForward(), let next = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        show(month: next)
    }

    /// WHY clear the selection (found in code review): otherwise the details below the grid kept
    /// showing a day from the PREVIOUS month, which isn't visible any more.
    private func show(month newMonth: Date) {
        month = newMonth
        selectedDay = nil
    }

    func select(_ cell: DayCell) {
        selectedDay = cell.date
    }

    #if DEBUG
    /// Debug builds only: 45 days of sample wake-ups to try the calendar in the Simulator.
    func addSampleData() {
        try? records.addSampleHistory(days: 45)
    }
    #endif

    // MARK: - Helpers

    static func status(of entries: [WakeEntry]) -> DayStatus {
        guard !entries.isEmpty else { return .none }
        let finished = entries.filter(\.isFinished)
        if finished.isEmpty { return .missed }
        return finished.contains { $0.snoozeCount > 0 } ? .snoozed : .clean
    }
}
