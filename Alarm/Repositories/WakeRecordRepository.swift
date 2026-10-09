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
//    ← USED BY:    RingingViewModel (open a record when ringing starts, finish it when up),
//                  Morning tab / stats (Phase 5)
//    → TALKS TO:   SwiftData ModelContext (same database as AlarmRepository)
//

import Foundation
import Observation
import SwiftData

@Observable
final class WakeRecordRepository {
    @ObservationIgnored private let context: ModelContext
    /// Keeps the database alive (see AlarmRepository.container for the story).
    @ObservationIgnored private let container: ModelContainer

    init(context: ModelContext) {
        self.context = context
        self.container = context.container
    }

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

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
