//
//  WakeRecordRepository.swift
//  RiseUp
//
//  LAYER: Repository
//  WHAT:  The only place that reads/writes `WakeRecord` rows (wake-up history).
//  DATA:  WakeRecord.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (one shared instance)
//    ← USED BY:    RingingViewModel (open a record when ringing starts, finish it when up, mood),
//                  MorningViewModel, RecordsViewModel, StatsViewModel (read `entries`)
//    → TALKS TO:   SwiftData ModelContext (same database as AlarmRepository)
//
//  SAME PATTERN AS AlarmRepository: `entries` is the single source of truth, refreshed inside
//  every write. ViewModels read it through computed properties, so the Morning tab updates by
//  itself the moment a wake-up finishes. Entries are VALUES (WakeEntry), never @Model objects.
//

import Foundation
import Observation
import SwiftData

@Observable
final class WakeRecordRepository {
    @ObservationIgnored private let context: ModelContext
    /// Keeps the database alive (see AlarmRepository.container for the story).
    @ObservationIgnored private let container: ModelContainer

    /// Every wake-up, newest first, as plain values. → read by the Morning / Records / Stats screens.
    private(set) var entries: [WakeEntry] = []

    init(context: ModelContext) {
        self.context = context
        self.container = context.container
        refresh()
    }

    /// Re-reads all records into `entries`.
    ///
    /// WHY no `throws` here: a failed read shows an empty history instead of crashing a screen.
    func refresh() {
        let descriptor = FetchDescriptor<WakeRecord>(sortBy: [SortDescriptor(\.ringStartedAt, order: .reverse)])
        entries = ((try? context.fetch(descriptor)) ?? []).map(WakeEntry.init)
    }

    /// Morning check-in (#17): saves how the user felt. `nil` clears it.
    /// ← CALLED BY: RingingViewModel.setMood (Success screen), MorningViewModel.setMood
    func setMood(_ mood: Mood?, forRecordID id: UUID) throws {
        let recordID = id
        var descriptor = FetchDescriptor<WakeRecord>(predicate: #Predicate { $0.id == recordID })
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { return }
        record.moodRawValue = mood?.rawValue
        try save()
    }

    #if DEBUG
    /// Debug builds only: fills the history with `days` days of believable wake-ups, so the
    /// calendar and charts can be tried in the Simulator without waiting a month.
    /// ← CALLED BY: StatsView / RecordsView "Add sample data (Debug)"
    func addSampleHistory(days: Int, now: Date = .now, calendar: Calendar = .current) throws {
        var generator = SystemRandomNumberGenerator()
        for offset in 1...max(days, 1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else { continue }
            if Int.random(in: 0..<10, using: &generator) == 0 { continue }        // ~1 day in 10: no alarm
            let ring = day.addingTimeInterval(TimeInterval((6 * 60 + Int.random(in: 0...75, using: &generator)) * 60))
            let snoozes = Int.random(in: 0...6, using: &generator) < 4 ? 0 : Int.random(in: 1...3, using: &generator)
            let finished = Int.random(in: 0..<12, using: &generator) != 0             // ~1 in 12 never finished
            let missionSeconds = Double(Int.random(in: 20...150, using: &generator))
            let record = WakeRecord(
                alarmID: UUID(),
                alarmTitle: "Sample",
                ringStartedAt: ring,
                dismissedAt: finished ? ring.addingTimeInterval(Double(snoozes) * 300 + missionSeconds) : nil,
                snoozeCount: snoozes,
                missionsCompleted: finished ? 1 : 0,
                missionSeconds: finished ? missionSeconds : 0,
                moodRawValue: finished ? Int.random(in: 2...5, using: &generator) : nil
            )
            context.insert(record)
        }
        try save()
    }
    #endif

    /// The record for this wake-up: re-uses an unfinished one from the last 3 hours
    /// (so snoozing doesn't create a new record each time), or starts a new one.
    ///
    /// ← CALLED BY: RingingViewModel.start()
    func openRecord(alarmID: UUID, alarmTitle: String, now: Date = .now) throws -> WakeRecord {
        let since = now.addingTimeInterval(-3 * 60 * 60)
        // LEARN: values used inside #Predicate must be plain local constants.
        let id = alarmID
        var descriptor = FetchDescriptor<WakeRecord>(
            predicate: #Predicate { $0.alarmID == id && $0.dismissedAt == nil && $0.ringStartedAt > since },
            sortBy: [SortDescriptor(\.ringStartedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let record = WakeRecord(alarmID: alarmID, alarmTitle: alarmTitle, ringStartedAt: now)
        context.insert(record)
        try save()
        return record
    }

    /// Most recent wake-ups first.
    func recent(limit: Int = 30) throws -> [WakeRecord] {
        var descriptor = FetchDescriptor<WakeRecord>(sortBy: [SortDescriptor(\.ringStartedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Writes pending changes, then refreshes `entries` (so every screen sees the change).
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
        refresh()
    }
}
