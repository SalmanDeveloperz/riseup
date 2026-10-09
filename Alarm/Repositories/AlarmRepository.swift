//
//  AlarmRepository.swift
//  RiseUp
//
//  LAYER: Repository
//  WHAT:  The ONLY place that reads/writes `WakeAlarm` rows in SwiftData, AND the
//         single source of truth for "the current list of alarms".
//  DATA:  reads + writes WakeAlarm and (through the cascade relationship) MissionConfig.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies.init (ONE shared instance, using the main ModelContext)
//    ← USED BY:    AlarmListViewModel (reads `alarms`, saves, deletes)
//                  AlarmLabViewModel (inserts/deletes lab alarms)
//                  RingingPlaceholderViewModel (fetch by id, save)
//    → TALKS TO:   SwiftData ModelContext → the database file on the device
//
//  LEARN: Why a repository?
//  ────────────────────────
//  SwiftUI offers `@Query` to fetch data straight inside a View. It's handy, but
//  then data logic lives in the UI layer, which makes MVVM messy and hard to test.
//  We send all database access through small "repository" classes instead:
//      View → ViewModel → Repository → SwiftData
//  The ViewModel never needs to know HOW data is stored, just "give me the alarms".
//
//  LEARN: "Single source of truth"
//  ──────────────────────────────
//  BUG WE HIT: the Alarm List kept its OWN copy of the alarms array. The AlarmKit Lab
//  (another screen) deleted alarms from the database, and when you went back to the
//  list, its cards read the deleted objects → SwiftData crashed the app.
//
//  FIX: there is now ONE live list, `alarms`, here in the repository. It's refreshed
//  inside every write (insert/delete/save), BEFORE SwiftUI gets a chance to redraw.
//  ViewModels don't copy it; they read `repository.alarms` directly. Because this class
//  is `@Observable`, every screen showing alarms updates automatically, whichever screen
//  made the change.
//

import Foundation
import Observation
import SwiftData

/// Read/write access to alarms + the always-fresh list of all alarms.
///
/// LEARN: this class runs on the main actor (the project default). That matches
/// `ModelContainer.mainContext`, which must only be used on the main thread.
@Observable
final class AlarmRepository {

    /// Every alarm, earliest time of day first. Always matches the database.
    ///
    /// → READ BY: AlarmListViewModel.alarms (which the Alarm List screen draws)
    private(set) var alarms: [WakeAlarm] = []

    /// LEARN: `@ObservationIgnored` = "don't track this property". The context never
    /// changes after init, so watching it would be wasted work.
    @ObservationIgnored private let context: ModelContext

    /// Keeps the database alive for as long as this repository exists.
    ///
    /// WHY (a crash we found in Xcode Previews): a `ModelContext` does NOT keep its
    /// `ModelContainer` (the database) alive. In a `#Preview`, `AppDependencies.preview()`
    /// is a local value that disappears once the preview is built, so the container was
    /// freed, and the next fetch crashed inside SwiftData. Holding it here fixes that everywhere.
    @ObservationIgnored private let container: ModelContainer

    init(context: ModelContext) {
        self.context = context
        self.container = context.container
        // Fill the list once at startup. If it fails, the list stays empty and the next
        // `refresh()` (e.g. when the Alarm List appears) tries again.
        try? refresh()
    }

    // MARK: - Read

    /// Re-reads all alarms from the database into `alarms`.
    ///
    /// ← CALLED BY: every write below, and AlarmListViewModel.load()
    func refresh() throws {
        alarms = try fetchAll()
    }

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

    /// Adds a new alarm (and its missions), saves to disk and refreshes `alarms`.
    func insert(_ alarm: WakeAlarm) throws {
        context.insert(alarm)
        try save()
    }

    /// Deletes an alarm (its missions too, cascade rule), saves and refreshes `alarms`.
    ///
    /// WHY refresh right here: the deleted object disappears from `alarms` in the same
    /// moment it's deleted, so no screen can ever draw it again.
    func delete(_ alarm: WakeAlarm) throws {
        context.delete(alarm)
        try save()
    }

    /// Replaces an alarm's missions with the given drafts (in that order). Call `save()` after.
    ///
    /// ← CALLED BY: AlarmEditorViewModel.save()
    /// WHY delete + re-create instead of editing each one: a draft list can have missions
    /// added, removed, reordered and changed. Replacing them all is simple and always correct.
    func replaceMissions(of alarm: WakeAlarm, with drafts: [MissionDraft]) {
        for old in alarm.missions {
            context.delete(old)
        }
        alarm.missions = drafts.enumerated().map { index, draft in
            MissionConfig(
                id: draft.id,
                type: draft.type,
                difficulty: draft.difficulty,
                repetitions: draft.repetitions,
                sortOrder: index
            )
        }
    }

    /// Writes all pending changes to disk, then refreshes `alarms` (order may have changed).
    ///
    /// LEARN: when you change a property on a fetched object (`alarm.isEnabled = false`),
    /// SwiftData notices automatically, but it's only written to disk on `save()`.
    /// We save right away so nothing is lost if the app is killed.
    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
        try refresh()
    }
}
