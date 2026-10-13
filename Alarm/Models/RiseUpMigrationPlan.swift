//
//  RiseUpMigrationPlan.swift
//  RiseUp
//
//  LAYER: Model (SwiftData)
//  WHAT:  The list of database versions and how to upgrade between them.
//  USED BY: ModelContainerFactory.
//

import SwiftData

/// Tells SwiftData every schema version that has ever shipped, oldest first.
///
/// LEARN: each schema change follows the same 4 steps (done for V2 on 2026-10-09):
///   1. Copy the latest SchemaVn.swift → SchemaVn+1.swift and make the change there.
///   2. Add `SchemaVn+1.self` to `schemas`.
///   3. Add a stage, e.g. `.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)`
///      (lightweight = SwiftData figures it out: new optional properties, new tables).
///      Changes SwiftData can't guess (e.g. splitting one property into two) use `.custom`.
///   4. Point the typealiases (bottom of the newest schema file) at the new models.
///
/// ← USED BY: ModelContainerFactory.make()
enum RiseUpMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// V1 → V2: adds `WakeAlarm.fixedFireDate` (nil for existing alarms) and the empty
    /// `WakeRecord` table. Both are "lightweight": SwiftData needs no help.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    /// V2 → V3 (2026-10-13): adds `WakeAlarm.wallpaperID`. Existing alarms get `nil`, which
    /// means "use the default wallpaper from Settings". Lightweight again.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
