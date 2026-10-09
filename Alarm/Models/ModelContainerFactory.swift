//
//  ModelContainerFactory.swift
//  RiseUp
//
//  LAYER: Model (SwiftData setup)
//  WHAT:  Creates the ModelContainer, which owns the database file.
//  USED BY: AppDependencies (real app + previews + tests).
//

import SwiftData

/// Builds the app's SwiftData container.
enum ModelContainerFactory {

    /// - Parameter inMemory: `true` keeps everything in RAM and throws it away when the
    ///   app closes. Used by SwiftUI Previews and unit tests so they never touch real data.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)   // ← the CURRENT schema
        let configuration = ModelConfiguration(
            "RiseUp",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        // WHY: in Phase 4 the home-screen widget needs to read alarms. The database will
        // then move into a shared "App Group" folder. No users exist yet, so moving it
        // then is safe; after launch it would need a careful file move.
        return try ModelContainer(
            for: schema,
            migrationPlan: RiseUpMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
