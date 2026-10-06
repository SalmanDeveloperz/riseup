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
/// LEARN: Right now there's only V1, so there's nothing to migrate. When we change a
/// model after release, we will:
///   1. Copy SchemaV1.swift → SchemaV2.swift and make the change there.
///   2. Add `SchemaV2.self` to `schemas`.
///   3. Add a stage, e.g. `.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)`
///      (lightweight = SwiftData figures it out, for example a new property with a default value).
///   4. Point the typealiases in SchemaV1.swift at the V2 models.
enum RiseUpMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
