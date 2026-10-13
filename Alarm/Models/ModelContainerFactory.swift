//
//  ModelContainerFactory.swift
//  RiseUp
//
//  LAYER: Model (SwiftData setup)
//  WHAT:  Creates the ModelContainer, which owns the database file.
//  USED BY: AppDependencies (real app + previews + tests).
//

import Foundation
import SwiftData

/// Builds the app's SwiftData container.
enum ModelContainerFactory {

    /// - Parameter inMemory: `true` keeps everything in RAM and throws it away when the
    ///   app closes. Used by SwiftUI Previews and unit tests so they never touch real data.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)   // ← the CURRENT schema
        let configuration = makeConfiguration(schema: schema, inMemory: inMemory)
        // WHY: in Phase 4 the home-screen widget needs to read alarms. The database will
        // then move into a shared "App Group" folder. No users exist yet, so moving it
        // then is safe; after launch it would need a careful file move.
        return try ModelContainer(
            for: schema,
            migrationPlan: RiseUpMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private static func makeConfiguration(schema: Schema, inMemory: Bool) -> ModelConfiguration {
        ModelConfiguration("RiseUp", schema: schema, isStoredInMemoryOnly: inMemory)
    }

    /// Renames a database file that can't be opened (and its helper files) to
    /// "RiseUp-damaged-<date>.store…", so a fresh one can be created. Nothing is deleted.
    /// ← CALLED BY: AppDependencies.openDatabase (only when opening failed twice)
    ///
    /// LEARN: SQLite keeps a database in up to 3 files: `.store`, `.store-shm` and `.store-wal`.
    static func setAsideDamagedStore() throws {
        let url = makeConfiguration(schema: Schema(versionedSchema: SchemaV3.self), inMemory: false).url
        let stamp = Int(Date.now.timeIntervalSince1970)
        let files = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard files.fileExists(atPath: source.path) else { continue }
            let target = url.deletingLastPathComponent()
                .appendingPathComponent("RiseUp-damaged-\(stamp).store\(suffix)")
            try files.moveItem(at: source, to: target)
        }
    }
}
