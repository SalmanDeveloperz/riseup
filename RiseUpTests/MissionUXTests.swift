//
//  MissionUXTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for "missions you can't miss" (#38)
//  WHAT:  • the editor's one-tap tiles: add with defaults, tap again = adjust, Photo/QR open their setup,
//           at most 3, never a double add
//         • the alarm card's "+ Add mission": saved straight away (and scheduled), blocked while a wake-up
//           is pending, rolled back if iOS refuses, harmless if the alarm was deleted meanwhile
//         • widgets: the mission names travel in the snapshot; old snapshots still load;
//           riseup://alarm/<id>/mission opens the Mission Picker for that alarm
//  DATA:  in-memory database, MockAlarmScheduler, a fresh AppCoordinator per test.
//
//  CONNECTIONS:
//    → TESTS: AlarmEditorViewModel.quickAddMission, MissionPickerViewModel(startingWith:),
//             AlarmListViewModel.addMission / save(_:toAlarm:) / handleMissionRequest, DeepLink,
//             AppCoordinator.open(.addMission), WidgetBridge.plan, WidgetAlarmEvent decoding
//

import Foundation
import SwiftData
import Testing
@testable import Alarm

@Suite("Missions you can't miss (#38)")
struct MissionUXTests {
    let container: ModelContainer
    let repository: AlarmRepository
    let scheduler = MockAlarmScheduler()
    let coordinator = AppCoordinator()
    let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
    }

    func makeEditor(alarmID: UUID? = nil) -> AlarmEditorViewModel {
        AlarmEditorViewModel(alarmID: alarmID, repository: repository, scheduler: scheduler, settings: settings,
                             wallpaperStore: MockWallpaperStore(), customSounds: MockCustomSoundLibrary(),
                             coordinator: coordinator)
    }

    func makeList() -> AlarmListViewModel {
        AlarmListViewModel(repository: repository, scheduler: scheduler,
                           sync: AlarmSyncService(repository: repository, scheduler: scheduler), coordinator: coordinator)
    }

    // MARK: - The tiles

    @Test("Every mission has exactly one tile, with a short name and a tagline")
    func tilesComplete() {
        #expect(MissionType.quickPickOrder.count == MissionType.allCases.count)
        #expect(Set(MissionType.quickPickOrder) == Set(MissionType.allCases))
        for type in MissionType.allCases {
            #expect(!type.shortTitle.isEmpty && type.shortTitle.count <= 8, "\(type)")
            #expect(!type.tagline.isEmpty, "\(type)")
        }
        #expect(MissionType.allCases.filter(\.needsSetup) == [.photo, .barcode])
    }

    @Test("One tap adds Math with sensible settings, no sheet; a second tap opens it to adjust")
    func oneTapAdd() {
        let editor = makeEditor()
        editor.quickAddMission(.math)
        #expect(editor.draft.missions.map(\.type) == [.math])
        #expect(editor.draft.missions.first == .defaults(for: .math).withID(editor.draft.missions[0].id))
        #expect(coordinator.sheet == nil, "no sheet for a one-tap mission")
        #expect(editor.hasMission(.math))

        editor.quickAddMission(.math)                         // tap the chosen tile again
        #expect(editor.draft.missions.count == 1, "never added twice")
        #expect(coordinator.sheet == .missionPicker(editing: editor.draft.missions[0], startingWith: nil))
    }

    @Test("Photo and QR tiles open their setup first; nothing is added until it's done")
    func setupTiles() {
        let editor = makeEditor()
        editor.quickAddMission(.photo)
        #expect(editor.draft.missions.isEmpty)
        #expect(coordinator.sheet == .missionPicker(editing: nil, startingWith: .photo))

        let picker = MissionPickerViewModel(editing: nil, startingWith: .photo, services: .preview(), coordinator: coordinator)
        #expect(picker.path == [.settings], "opens on the photo's settings")
        #expect(picker.draft?.type == .photo && !picker.isEditing)

        var registered = MissionDraft.defaults(for: .barcode)
        registered.textPayload = "4006381333931"
        coordinator.completeMissionPicker(with: registered)  // as if the user scanned a code and tapped Add
        #expect(editor.draft.missions.map(\.type) == [.barcode])
    }

    @Test("At most three missions: other tiles switch off, chosen ones can still be adjusted")
    func limit() {
        let editor = makeEditor()
        for type in [MissionType.math, .steps, .shake] { editor.quickAddMission(type) }
        #expect(editor.draft.missions.count == 3)
        #expect(!editor.isTileEnabled(.memory))
        #expect(editor.isTileEnabled(.math))
        editor.quickAddMission(.memory)
        #expect(editor.draft.missions.count == 3, "a fourth is never added")
        editor.removeMission(editor.draft.missions[0])
        #expect(editor.isTileEnabled(.memory))
    }

    @Test("Saved from the editor: the tile's mission is stored and the alarm is scheduled")
    func editorSaves() async throws {
        let editor = makeEditor()
        editor.quickAddMission(.steps)
        await editor.save()
        let alarm = try #require(repository.alarms.first)
        #expect(alarm.sortedMissions.map(\.type) == [.steps])
        #expect(scheduler.scheduledIDs.contains(alarm.id))
    }

    // MARK: - "+ Add mission" on the alarm card

    @Test("Card: pick a mission → saved to the alarm and scheduled, no editor")
    func cardAddsAndSaves() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        let list = makeList()

        list.addMission(toAlarm: alarm.id)
        #expect(coordinator.sheet == .missionPicker(editing: nil, startingWith: nil))
        await list.save(.defaults(for: .memory), toAlarm: alarm.id)     // what the picker's callback runs
        #expect(alarm.sortedMissions.map(\.type) == [.memory])
        #expect(scheduler.scheduledIDs.contains(alarm.id))
        #expect(coordinator.alarmsPath.isEmpty, "the editor never opened")
    }

    @Test("Card: an existing mission is kept; a switched-off alarm is saved but not scheduled")
    func cardKeepsExisting() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0, isEnabled: false)
        try repository.insert(alarm)
        repository.replaceMissions(of: alarm, with: [.defaults(for: .math)])
        try repository.save()

        await makeList().save(.defaults(for: .shake), toAlarm: alarm.id)
        #expect(alarm.sortedMissions.map(\.type) == [.math, .shake])
        #expect(!scheduler.scheduledIDs.contains(alarm.id))
    }

    @Test("Card: blocked while the alarm's wake-up is pending (the lock)")
    func cardRespectsLock() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        scheduler.pendingWakeUpIDs = [alarm.id]
        let list = makeList()

        list.addMission(toAlarm: alarm.id)
        #expect(coordinator.sheet == nil)
        #expect(list.errorMessage == AlarmListViewModel.lockedMessage)
        await list.save(.defaults(for: .math), toAlarm: alarm.id)   // the lock started while the sheet was open
        #expect(alarm.missions.isEmpty)
    }

    @Test("Card: if iOS refuses, the mission is taken off again and the user is told")
    func cardRollsBack() async throws {
        struct Refused: LocalizedError { var errorDescription: String? { "iOS said no." } }
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        scheduler.scheduleError = Refused()
        let list = makeList()

        await list.save(.defaults(for: .math), toAlarm: alarm.id)
        #expect(alarm.missions.isEmpty, "the card never shows a mission that isn't protecting the alarm")
        #expect(list.errorMessage?.contains("iOS said no.") == true)
    }

    @Test("Card: the alarm was deleted while the picker was open → nothing happens")
    func cardDeletedAlarm() async throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        let id = alarm.id
        let list = makeList()
        list.delete(alarmID: id)
        await list.save(.defaults(for: .math), toAlarm: id)
        #expect(repository.alarms.isEmpty && list.errorMessage == nil)
    }

    // MARK: - Widgets

    @Test("riseup://alarm/<id>/mission → the Alarms tab opens the Mission Picker for that alarm")
    func widgetLink() throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        let url = WidgetShared.addMissionURL(alarm.id)
        #expect(DeepLink(url: url) == .addMission(alarm.id))
        #expect(DeepLink(url: URL(string: "riseup://alarm/\(alarm.id.uuidString)/nonsense")!) == nil)
        #expect(DeepLink(url: WidgetShared.alarmURL(alarm.id)) == .alarm(alarm.id), "the old link still works")

        coordinator.selectedTab = .settings
        coordinator.open(.addMission(alarm.id))
        #expect(coordinator.selectedTab == .alarms && coordinator.missionRequestAlarmID == alarm.id)

        let list = makeList()
        list.handleMissionRequest()                           // what AlarmListView's .task(id:) does
        #expect(coordinator.sheet == .missionPicker(editing: nil, startingWith: nil))
        #expect(coordinator.missionRequestAlarmID == nil, "handled once, then forgotten")
    }

    @Test("The snapshot carries mission names; an old snapshot without them still loads")
    func widgetSnapshot() throws {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        try repository.insert(alarm)
        repository.replaceMissions(of: alarm, with: [.defaults(for: .math), .defaults(for: .barcode)])
        let event = try #require(WidgetBridge.plan(alarms: [alarm], defaultWallpaper: .standard, now: .now).first?.event)
        #expect(event.missionTitles == ["Math", "QR code"] && event.hasMissions)

        let old = #"{"alarmID":"\#(UUID().uuidString)","fireDate":0,"title":"Old","missionSymbols":[],"soundTitle":"Radar","wallpaperTitle":"Aurora"}"#
        let decoded = try JSONDecoder().decode(WidgetAlarmEvent.self, from: Data(old.utf8))
        #expect(decoded.missionTitles == nil && !decoded.hasMissions)
    }
}

private extension MissionDraft {
    /// The same settings with another id (ids are random, so compare everything else).
    func withID(_ id: UUID) -> MissionDraft {
        var copy = self
        copy.id = id
        return copy
    }
}
