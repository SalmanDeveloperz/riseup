//
//  WallpaperTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for alarm wallpapers (#32) and Developer mode
//  WHAT:  • Wallpaper names survive saving/loading; unknown names are ignored safely
//         • "Surprise me" is stable all day and changes the next day
//         • the energy clock speeds up smoothly (no jumps) and levels stay 0…1
//         • a REAL V2 database file upgrades to V3 without losing alarms (migration)
//         • photos: saved small, loaded, deleted
//         • the editor saves the wallpaper; the ringing screen uses the alarm's or the default one
//         • Developer mode needs 7 quick taps
//  DATA:  in-memory databases, temporary files.
//
//  CONNECTIONS:
//    → TESTS: Wallpaper, WallpaperEnergy, RiseUpMigrationPlan, FileWallpaperStore,
//             AlarmEditorViewModel, RingingViewModel, SettingsViewModel
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Alarm

@Suite("Wallpapers")
struct WallpaperTests {

    // MARK: - Names

    @Test("Every wallpaper survives being saved as text", arguments: LiveWallpaper.allCases)
    func liveRoundTrip(style: LiveWallpaper) {
        let wallpaper = Wallpaper.live(style)
        #expect(Wallpaper(rawValue: wallpaper.rawValue) == wallpaper)
    }

    @Test("Photo and Surprise names round-trip; unknown names become nil")
    func otherRoundTrips() {
        let id = UUID()
        #expect(Wallpaper(rawValue: Wallpaper.photo(id: id).rawValue) == .photo(id: id))
        #expect(Wallpaper(rawValue: "surprise") == .surprise)
        #expect(Wallpaper(rawValue: "live.removedOne") == nil)
        #expect(Wallpaper(rawValue: "photo.not-a-uuid") == nil)
        #expect(Wallpaper(rawValue: "") == nil)
    }

    @Test("Each live wallpaper is in exactly one category; Saved and My Photos list other things")
    func categories() {
        let listed = WallpaperCategory.allCases.flatMap(\.liveWallpapers)
        #expect(Set(listed) == Set(LiveWallpaper.allCases))
        #expect(listed.count == LiveWallpaper.allCases.count)
        #expect(WallpaperCategory.myPhotos.liveWallpapers.isEmpty)
        #expect(WallpaperCategory.saved.liveWallpapers.isEmpty)
        #expect(WallpaperCategory.world.liveWallpapers.count == 11)
    }

    @Test("Every icon name used for sounds and wallpapers exists in SF Symbols")
    func symbolsExist() {
        let names = AlarmSound.allCases.map(\.systemImage) + WallpaperCategory.allCases.map(\.systemImage)
        for name in names {
            #expect(UIImage(systemName: name) != nil, "missing SF Symbol: \(name)")
        }
    }

    @Test("Surprise me: the same all day, different tomorrow")
    func surprise() {
        let calendar = Calendar(identifier: .gregorian)
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let evening = morning.addingTimeInterval(10 * 3600)
        let tomorrow = morning.addingTimeInterval(24 * 3600)
        let today = Wallpaper.surprise.resolved(on: morning, calendar: calendar)
        #expect(today == Wallpaper.surprise.resolved(on: evening, calendar: calendar))
        #expect(today != Wallpaper.surprise.resolved(on: tomorrow, calendar: calendar))
        #expect(today != .surprise, "always resolves to a real wallpaper")
        #expect(Wallpaper.live(.aurora).resolved() == .live(.aurora), "others stay as they are")
    }

    // MARK: - Energy

    @Test("Energy level rises from 0 to 1 and stays there")
    func energyLevel() {
        let start = Date(timeIntervalSince1970: 0)
        let ramp = WallpaperEnergy.ramp(start: start, duration: 40)
        #expect(ramp.level(at: start) == 0)
        #expect(ramp.level(at: start.addingTimeInterval(20)) == 0.5)
        #expect(ramp.level(at: start.addingTimeInterval(400)) == 1)
        #expect(ramp.level(at: start.addingTimeInterval(-5)) == 0)
        #expect(WallpaperEnergy.fixed(3).level(at: start) == 1)
    }

    @Test("The animation clock never jumps and never goes backwards")
    func energyClock() {
        let ramp = WallpaperEnergy.ramp(start: .now, duration: 40)
        let boost = 2.5
        // Continuous where the ramp ends:
        let before = ramp.clock(elapsed: 40 - 1e-6, boost: boost)
        let after = ramp.clock(elapsed: 40 + 1e-6, boost: boost)
        #expect(abs(after - before) < 1e-4)
        // Always moving forward, and faster at the end than at the start:
        var previous = -1.0
        for step in 0...120 {
            let value = ramp.clock(elapsed: Double(step), boost: boost)
            #expect(value > previous)
            previous = value
        }
        let early = ramp.clock(elapsed: 1, boost: boost) - ramp.clock(elapsed: 0, boost: boost)
        let late = ramp.clock(elapsed: 101, boost: boost) - ramp.clock(elapsed: 100, boost: boost)
        #expect(abs(early - 1) < 0.05, "starts at normal speed")
        #expect(abs(late - (1 + boost)) < 1e-9, "ends at full speed")
    }

    // MARK: - Database upgrade

    @Test("A V2 database file upgrades to V3 and keeps its alarms")
    func migrationV2toV3() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("RiseUp.store")
        let id = UUID()

        // 1. Yesterday's app: write a V2 database file.
        do {
            let v2 = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(for: v2, configurations: [ModelConfiguration(schema: v2, url: url)])
            let context = ModelContext(container)
            context.insert(SchemaV2.WakeAlarm(id: id, hour: 6, minute: 45, label: "Gym"))
            try context.save()
        }

        // 2. Today's app: open the same file with V3 + the migration plan.
        let v3 = Schema(versionedSchema: SchemaV3.self)
        let container = try ModelContainer(for: v3, migrationPlan: RiseUpMigrationPlan.self,
                                           configurations: [ModelConfiguration(schema: v3, url: url)])
        let alarms = try ModelContext(container).fetch(FetchDescriptor<WakeAlarm>())
        let alarm = try #require(alarms.first)
        #expect(alarms.count == 1)
        #expect(alarm.id == id && alarm.hour == 6 && alarm.minute == 45 && alarm.label == "Gym")
        #expect(alarm.wallpaperID == nil, "old alarms use the default wallpaper")
    }

    // MARK: - Photo store

    @Test("Photos are saved small, loaded and deleted")
    func photoStore() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileWallpaperStore(folder: folder)
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let id = try await store.add(try #require(big.pngData()))

        #expect(store.photoIDs() == [id])
        let loaded = try #require(await store.image(for: id))
        #expect(max(loaded.size.width * loaded.scale, loaded.size.height * loaded.scale) <= CGFloat(FileWallpaperStore.maxSide))

        store.delete(id)
        #expect(store.photoIDs().isEmpty)
        #expect(await store.image(for: id) == nil)
        await #expect(throws: WallpaperStoreError.self) { try await store.add(Data("not an image".utf8)) }
    }

    // MARK: - Editor & ringing

    @Test("The editor saves the chosen wallpaper; 'Default' saves nothing")
    func editorSavesWallpaper() async throws {
        let (repository, settings) = try makeRepositoryAndSettings()
        let editor = AlarmEditorViewModel(alarmID: nil, repository: repository, scheduler: MockAlarmScheduler(),
                                          settings: settings, wallpaperStore: MockWallpaperStore(), coordinator: AppCoordinator())
        #expect(editor.wallpaperTitle == "Golden Hour")
        #expect(editor.wallpaperSubtitle == "Default from Settings")
        editor.draft.wallpaper = .live(.synthwave)
        await editor.save()
        #expect(repository.alarms.first?.wallpaperID == "live.synthwave")
    }

    @Test("Ringing uses the alarm's wallpaper, or the default from Settings")
    func ringingWallpaper() throws {
        let (repository, settings) = try makeRepositoryAndSettings()
        let container = try ModelContainerFactory.make(inMemory: true)
        let records = WakeRecordRepository(context: container.mainContext)
        settings.defaultWallpaper = .live(.ocean)
        let plain = WakeAlarm(hour: 7, minute: 0)
        let themed = WakeAlarm(hour: 8, minute: 0, wallpaperID: "live.nebula")
        try repository.insert(plain)
        try repository.insert(themed)

        func ring(_ alarm: WakeAlarm) -> Wallpaper? {
            let viewModel = RingingViewModel(
                alarmID: alarm.id, repository: repository, records: records, scheduler: MockAlarmScheduler(),
                audio: MockAudioService(), timeAnnouncer: MockTimeAnnouncer(), sleepSounds: MockSleepSoundPlayer(),
                settings: settings, wallpaperStore: MockWallpaperStore(), missionServices: .preview(),
                coordinator: AppCoordinator())
            viewModel.start()
            return viewModel.info?.wallpaper
        }
        #expect(ring(plain) == .live(.ocean))
        #expect(ring(themed) == .live(.nebula))
    }

    // MARK: - Developer mode

    @Test("Developer mode needs 7 quick taps on the version number")
    func developerMode() {
        let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
        let viewModel = SettingsViewModel(settings: settings, coordinator: AppCoordinator())
        let start = Date(timeIntervalSince1970: 0)
        #expect(!settings.showsDeveloperTools, "hidden by default")

        for tap in 0..<6 { viewModel.versionTapped(now: start.addingTimeInterval(Double(tap) * 0.3)) }
        #expect(!settings.showsDeveloperTools, "6 taps aren't enough")
        viewModel.versionTapped(now: start.addingTimeInterval(1.8))
        #expect(settings.showsDeveloperTools)

        // Slow taps (more than 1.5 s apart) never add up.
        for tap in 0..<10 { viewModel.versionTapped(now: start.addingTimeInterval(100 + Double(tap) * 2)) }
        #expect(settings.showsDeveloperTools, "unchanged by slow taps")
    }

    private func makeRepositoryAndSettings() throws -> (AlarmRepository, AppSettings) {
        let container = try ModelContainerFactory.make(inMemory: true)
        let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
        return (AlarmRepository(context: container.mainContext), settings)
    }
}

// MARK: - Scene Player (#33)

@Suite("Scene player")
struct ScenePlayerTests {
    let audio = MockAudioService()
    let coordinator = AppCoordinator()
    let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)

    func makePicker(selected: Wallpaper? = nil, sound: AlarmSound = .radar) -> WallpaperPickerViewModel {
        WallpaperPickerViewModel(selected: selected, allowsDefault: true, defaultWallpaper: .standard, currentSound: sound,
                                 store: MockWallpaperStore(), audio: audio, settings: settings, coordinator: coordinator)
    }

    @Test("Opening a scene plays its own sound, looping")
    func opensWithSound() {
        let picker = makePicker()
        picker.category = .world
        picker.openPlayer(.live(.kyotoBlossoms))
        #expect(picker.isShowingPlayer)
        #expect(audio.previewedSound == .koto)
        #expect(audio.isPreviewLooping)
        #expect(picker.playlist.count == 11, "the whole tab is the playlist")
    }

    @Test("Next and previous step through the tab, wrap around and switch the sound")
    func nextPrevious() {
        let picker = makePicker()
        picker.category = .world
        picker.openPlayer(.live(.cityLights))                 // the last world scene
        picker.next()
        #expect(picker.playing == .live(.kyotoBlossoms), "wraps to the first")
        #expect(audio.previewedSound == .koto)
        picker.previous()
        #expect(picker.playing == .live(.cityLights))
        #expect(audio.previewedSound == .jazzPiano)
    }

    @Test("Pause stops the sound; changing scene while paused stays quiet")
    func pause() {
        let picker = makePicker()
        picker.category = .world
        picker.openPlayer(.live(.himalaya))
        picker.togglePlay()
        #expect(!picker.isSoundPlaying)
        #expect(audio.previewedSound == nil)
        picker.next()
        #expect(audio.previewedSound == nil)
        picker.togglePlay()
        #expect(audio.previewedSound == .accordion, "Paris comes after Himalaya")
    }

    @Test("♥ saves a scene into the Saved tab, and again removes it")
    func bookmarks() {
        let picker = makePicker()
        picker.category = .space
        picker.openPlayer(.live(.nebula))
        picker.toggleSaved()
        #expect(picker.isSaved(.live(.nebula)))
        #expect(picker.wallpapers(in: .saved) == [.live(.nebula)])
        picker.toggleSaved()
        #expect(picker.wallpapers(in: .saved).isEmpty)
    }

    @Test("Your own photos play the alarm's current sound and never change it")
    func photosKeepTheSound() async {
        let picker = makePicker(sound: .bell)
        let photo = Wallpaper.photo(id: UUID())
        picker.openPlayer(photo)
        #expect(audio.previewedSound == .bell)
        #expect(!picker.hasSignatureSound(photo))
    }

    @Test("'Use wallpaper + sound' gives the editor both; 'Wallpaper only' keeps the alarm's sound")
    func useSceneInEditor() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let editor = AlarmEditorViewModel(alarmID: nil, repository: AlarmRepository(context: container.mainContext),
                                          scheduler: MockAlarmScheduler(), settings: settings,
                                          wallpaperStore: MockWallpaperStore(), coordinator: coordinator)
        let originalSound = editor.draft.sound

        editor.chooseWallpaper()                               // registers the editor's callback
        let picker = makePicker(sound: originalSound)
        picker.category = .world
        picker.openPlayer(.live(.tropicalIsland))
        await picker.use(withSound: false)
        #expect(editor.draft.wallpaper == .live(.tropicalIsland))
        #expect(editor.draft.sound == originalSound)
        #expect(audio.previewedSound == nil, "the sound stops when the player closes")

        editor.chooseWallpaper()
        picker.openPlayer(.live(.saharaDunes))
        await picker.use(withSound: true)
        #expect(editor.draft.wallpaper == .live(.saharaDunes))
        #expect(editor.draft.sound == .desertOud)
    }
}
