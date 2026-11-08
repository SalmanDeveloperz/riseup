//
//  StoreRelocation.swift
//  RiseUp
//
//  LAYER: Model (SwiftData setup: runs once, BEFORE the database is opened)
//  WHAT:  Moves the database from where RiseUp kept it before widgets existed (the app's own
//         folder) to where SwiftData looks for it now (the App Group folder), so people who
//         update keep their alarms.
//  DATA:  files only, never their contents:
//           RiseUp.store, RiseUp.store-shm, RiseUp.store-wal  (the SQLite database)
//           .RiseUp_SUPPORT/                                  (photo-mission pictures, `.externalStorage`)
//
//  CONNECTIONS:
//    ← CALLED BY: ModelContainerFactory.make (right before `ModelContainer(...)` opens the file)
//    ← TESTED BY: RiseUpTests/StoreRelocationTests
//    → FileManager: createDirectory / moveItem / removeItem (only stray helper files, see below)
//
//  WHY this file exists (bug found 2026-10-18 while testing an update on a Simulator):
//    `ModelConfiguration("RiseUp", …)` doesn't say WHERE the file goes, so SwiftData decides:
//      • app WITHOUT an App Group → <app folder>/Library/Application Support/RiseUp.store
//      • app WITH an App Group    → <group folder>/Library/Application Support/RiseUp.store
//    The widgets commit added an App Group (for WidgetSnapshot), and SwiftData silently started
//    using the group folder. An updated app found NO database there, created an empty one and
//    showed "No alarms yet". Worse: AlarmSyncService then saw iOS alarms with no database row and
//    cancelled them. The old file was still there, just never opened again.
//
//  LEARN: every iPhone app lives in a "sandbox": its own folders that no other app can read. An
//  App Group is one extra folder that several of YOUR programs (the app + its widget) may share.
//

import Foundation

/// Moves an old database into the folder SwiftData uses today, once.
nonisolated enum StoreRelocation {

    /// What `moveIfNeeded` did. (Tests check it; the app writes it to the trace.)
    enum Outcome: Equatable {
        /// Nothing to do: no old database, or it's already in the right folder.
        case notNeeded
        /// The old database (and its helper files) now live in the new folder.
        case moved
        /// BOTH folders have a database. We never pick one by overwriting: the new one is used
        /// and the old one is left exactly where it is (nothing is lost, it can be rescued by hand).
        case keptBoth
    }

    /// The helper files SQLite/SwiftData keep next to `RiseUp.store`.
    ///
    /// LEARN: SQLite writes changes into the `-wal` file first ("write-ahead log") and copies them
    /// into the main file later. Moving the main file WITHOUT its `-wal` would lose the newest
    /// changes, so all of them always travel together.
    /// `.RiseUp_SUPPORT` is the hidden folder where `@Attribute(.externalStorage)` keeps big data
    /// (the photo mission's reference pictures).
    static func helperNames(for storeFileName: String) -> [String] {
        let baseName = (storeFileName as NSString).deletingPathExtension   // "RiseUp.store" → "RiseUp"
        return [storeFileName + "-shm", storeFileName + "-wal", ".\(baseName)_SUPPORT"]
    }

    // MARK: - The real app

    /// Moves `RiseUp.store` from the app's own Application Support folder to the folder of
    /// `storeURL` (where SwiftData is about to open it), if that's needed.
    /// ← CALLED BY: ModelContainerFactory.make
    ///
    /// WHY it throws instead of carrying on: opening the database after a failed move would
    /// create an EMPTY database in the new folder, and the next launch would then see two of
    /// them (`.keptBoth`) and never move the real one. Throwing lets AppDependencies.openDatabase
    /// retry, and the move can always continue where it stopped (see `moveIfNeeded`).
    @discardableResult
    static func moveLegacyStoreIfNeeded(to storeURL: URL) throws -> Outcome {
        let outcome = try moveIfNeeded(
            storeFileName: storeURL.lastPathComponent,
            from: URL.applicationSupportDirectory,          // where the pre-widget app kept it
            to: storeURL.deletingLastPathComponent()        // where SwiftData looks today
        )
        if outcome != .notNeeded {
            Trace.log(.database, "StoreRelocation.moveLegacyStoreIfNeeded() → \(outcome)")
        }
        return outcome
    }

    // MARK: - The rule (pure file moves, tested with temporary folders)

    /// Moves `storeFileName` and its helpers from `oldFolder` to `newFolder`.
    ///
    /// Safe to stop at ANY moment (battery dies, app killed) and run again:
    ///   1. the helpers move first and the main file moves LAST, so
    ///   2. "the main file is still in the old folder" always means "not finished yet", and the
    ///      next run simply moves whatever is still left.
    ///
    /// LEARN: `moveItem` inside one disk is a rename: instant, and it either fully happens or not
    /// at all. The app folder and the App Group folder are on the same disk.
    static func moveIfNeeded(
        storeFileName: String,
        from oldFolder: URL,
        to newFolder: URL,
        fileManager files: FileManager = .default
    ) throws -> Outcome {
        guard oldFolder.standardizedFileURL != newFolder.standardizedFileURL else { return .notNeeded }

        let oldStore = oldFolder.appendingPathComponent(storeFileName)
        let newStore = newFolder.appendingPathComponent(storeFileName)
        guard files.fileExists(atPath: oldStore.path) else { return .notNeeded }
        guard !files.fileExists(atPath: newStore.path) else { return .keptBoth }

        try files.createDirectory(at: newFolder, withIntermediateDirectories: true)

        for name in helperNames(for: storeFileName) {
            let source = oldFolder.appendingPathComponent(name)
            let target = newFolder.appendingPathComponent(name)
            guard files.fileExists(atPath: source.path) else { continue }   // already moved, or never existed
            // WHY delete here: there is no database in the new folder (checked above), so a
            // helper file there belongs to nothing. The REAL one is `source`, and it must win.
            if files.fileExists(atPath: target.path) { try files.removeItem(at: target) }
            try files.moveItem(at: source, to: target)
        }
        try files.moveItem(at: oldStore, to: newStore)                       // LAST: "done"
        return .moved
    }
}
