//
//  StoreRelocationTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for moving the database into the App Group folder
//  WHAT:  • an update from a pre-widget build keeps its alarms (a REAL database file + photo data)
//         • a new install, an already-moved database and "the same folder" do nothing
//         • two databases: nothing is overwritten or deleted
//         • a move that was interrupted finishes on the next launch, without losing the -wal file
//  DATA:  temporary folders only ("old" = the app's folder, "new" = the App Group folder).
//         The real app folders are never touched.
//
//  CONNECTIONS:
//    → TESTS: StoreRelocation.moveIfNeeded / helperNames, RiseUpMigrationPlan (V3 → V4)
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Database folder move (pre-widget update)")
struct StoreRelocationTests {
    private let store = "RiseUp.store"

    /// Two empty temporary folders, deleted after the test.
    private func makeFolders() throws -> (old: URL, new: URL, cleanUp: () -> Void) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let old = root.appendingPathComponent("AppFolder/Library/Application Support", isDirectory: true)
        let new = root.appendingPathComponent("GroupFolder/Library/Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        return (old, new, { try? FileManager.default.removeItem(at: root) })
    }

    private func write(_ text: String, to url: URL) throws { try Data(text.utf8).write(to: url) }
    private func read(_ url: URL) throws -> String { String(decoding: try Data(contentsOf: url), as: UTF8.self) }
    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    // MARK: - The bug itself

    @Test("An update from a pre-widget build keeps its alarms and photo data")
    func updateKeepsAlarms() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        let id = UUID()

        // 1. The pre-widget app (SchemaV3) saves an alarm in ITS folder.
        do {
            let v3 = Schema(versionedSchema: SchemaV3.self)
            let container = try ModelContainer(for: v3, configurations: [
                ModelConfiguration(schema: v3, url: old.appendingPathComponent(store))
            ])
            let context = ModelContext(container)
            context.insert(SchemaV3.WakeAlarm(id: id, hour: 6, minute: 30, label: "Work"))
            try context.save()
        }
        // A stand-in for a photo-mission picture kept by `.externalStorage`.
        let support = old.appendingPathComponent(".RiseUp_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try write("photo", to: support.appendingPathComponent("ABC"))

        // 2. Today's app starts: the files move, then V4 + the migration plan open them.
        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .moved)
        #expect(!exists(old.appendingPathComponent(store)), "nothing is left behind")

        let v4 = Schema(versionedSchema: SchemaV4.self)
        let container = try ModelContainer(for: v4, migrationPlan: RiseUpMigrationPlan.self, configurations: [
            ModelConfiguration(schema: v4, url: new.appendingPathComponent(store))
        ])
        let alarms = try ModelContext(container).fetch(FetchDescriptor<WakeAlarm>())
        let alarm = try #require(alarms.first)
        #expect(alarms.count == 1)
        #expect(alarm.id == id && alarm.hour == 6 && alarm.minute == 30 && alarm.label == "Work")
        #expect(try read(new.appendingPathComponent(".RiseUp_SUPPORT/_EXTERNAL_DATA/ABC")) == "photo")
    }

    // MARK: - Nothing to do

    @Test("A new install has nothing to move and creates nothing")
    func freshInstall() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .notNeeded)
        #expect(!exists(new))
    }

    @Test("Already in the right folder (no App Group): nothing to do")
    func sameFolder() throws {
        let (old, _, cleanUp) = try makeFolders()
        defer { cleanUp() }
        try write("db", to: old.appendingPathComponent(store))
        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: old) == .notNeeded)
        #expect(try read(old.appendingPathComponent(store)) == "db")
    }

    @Test("Second launch after the move: nothing to do")
    func secondLaunch() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        try write("db", to: old.appendingPathComponent(store))
        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .moved)
        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .notNeeded)
        #expect(try read(new.appendingPathComponent(store)) == "db")
    }

    // MARK: - Negative cases

    @Test("Both folders have a database: nothing is overwritten or deleted")
    func keepsBoth() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try write("old db", to: old.appendingPathComponent(store))
        try write("old wal", to: old.appendingPathComponent(store + "-wal"))
        try write("new db", to: new.appendingPathComponent(store))

        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .keptBoth)
        #expect(try read(old.appendingPathComponent(store)) == "old db")
        #expect(try read(old.appendingPathComponent(store + "-wal")) == "old wal")
        #expect(try read(new.appendingPathComponent(store)) == "new db")
    }

    @Test("A move interrupted halfway (app killed) finishes on the next launch")
    func resumesAfterInterruption() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        // State after a crash: the -wal already moved, the main file and -shm didn't.
        try write("db", to: old.appendingPathComponent(store))
        try write("shm", to: old.appendingPathComponent(store + "-shm"))
        try write("newest changes", to: new.appendingPathComponent(store + "-wal"))

        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .moved)
        #expect(try read(new.appendingPathComponent(store)) == "db")
        #expect(try read(new.appendingPathComponent(store + "-shm")) == "shm")
        #expect(try read(new.appendingPathComponent(store + "-wal")) == "newest changes", "the moved -wal survives")
        #expect(!exists(old.appendingPathComponent(store)) && !exists(old.appendingPathComponent(store + "-shm")))
    }

    @Test("A stray helper file in the new folder never replaces the real one")
    func realHelperWins() throws {
        let (old, new, cleanUp) = try makeFolders()
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try write("db", to: old.appendingPathComponent(store))
        try write("real wal", to: old.appendingPathComponent(store + "-wal"))
        try write("stray", to: new.appendingPathComponent(store + "-wal"))

        #expect(try StoreRelocation.moveIfNeeded(storeFileName: store, from: old, to: new) == .moved)
        #expect(try read(new.appendingPathComponent(store + "-wal")) == "real wal")
    }

    @Test("The helper files that travel with the database")
    func helperNames() {
        #expect(StoreRelocation.helperNames(for: "RiseUp.store") == ["RiseUp.store-shm", "RiseUp.store-wal", ".RiseUp_SUPPORT"])
    }
}
