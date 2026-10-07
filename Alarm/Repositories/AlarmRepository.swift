//
//  AlarmRepository.swift
//  RiseUp
//
//  LAYER: Repository
//  WHAT:  The ONLY place that reads/writes `WakeAlarm` rows in SwiftData.
//  USED BY: ViewModels (Alarm List, Editor, Ringing, AlarmKit Lab…).
//  DATA:  reads + writes WakeAlarm and (through the cascade relationship) MissionConfig.
//
//  LEARN: Why a repository?
//  ────────────────────────
//  SwiftUI offers `@Query` to fetch data straight inside a View. It's handy, but
//  then data logic lives in the UI layer, which makes MVVM messy and hard to test.
//  We send all database access through small "repository" classes instead:
//      View → ViewModel → Repository → SwiftData
//  The ViewModel never needs to know HOW data is stored, just "give me the alarms".
//

import Foundation
import SwiftData

/// Read/write access to alarms.
///
/// LEARN: this class runs on the main actor (the project default). That matches
/// `ModelContainer.mainContext`, which must only be used on the main thread.
final class AlarmRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Read

    /// All alarms, earliest time of day first (6:00 before 7:30).
    func fetchAll() throws -> [WakeAlarm] {
        // LEARN: `FetchDescriptor` describes a query: which type, how to filter
        // (`predicate`), and how to sort.
        let descriptor = FetchDescriptor<WakeAlarm>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )
        return try context.fetch(descriptor)
    }

    /// One alarm by its ID, or `nil` if it was deleted.
    func fetch(id: UUID) throws -> WakeAlarm? {
        // LEARN: `#Predicate` is a type-checked filter. SwiftData turns it into a
        // database query. Plain Swift values (like `id`) must be copied into a local
        // constant before use inside it.
        let alarmID = id
        var descriptor = FetchDescriptor<WakeAlarm>(predicate: #Predicate { $0.id == alarmID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Write

    /// Adds a new alarm (and its missions) and saves to disk.
    func insert(_ alarm: WakeAlarm) throws {
        context.insert(alarm)
        try save()
    }

    /// Deletes an alarm. Its missions are deleted too (cascade rule).
    func delete(_ alarm: WakeAlarm) throws {
        context.delete(alarm)
        try save()
    }

    /// Writes all pending changes to disk.
    ///
    /// LEARN: when you change a property on a fetched object (`alarm.isEnabled = false`),
    /// SwiftData notices automatically, but it's only written to disk on `save()`.
    /// We save right away so nothing is lost if the app is killed.
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
