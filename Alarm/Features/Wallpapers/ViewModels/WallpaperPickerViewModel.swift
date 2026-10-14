//
//  WallpaperPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #32 Wallpaper Picker + Screen #33 Scene Player)
//  WHAT:  • Picker: categories of live wallpapers (incl. Around the World), ♥ Saved, "Surprise me",
//           your own photos (add / delete).
//         • Scene Player: full screen, the wallpaper AND its sound play together, with
//           ▶︎/⏸, ⏮ ⏭ (or swipe), ♥ bookmark, and "Use wallpaper + sound" / "Wallpaper only".
//  DATA:  reads/writes photo files (WallpaperStore) and bookmarks (AppSettings.savedWallpapers).
//         Doesn't touch the database: the editor (or Settings) saves the choice.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .wallpaperPicker)
//    ← OPENED BY:  AlarmEditorViewModel.chooseWallpaper(), SettingsViewModel.chooseDefaultWallpaper()
//    → STORE:      WallpaperStoring.add / image / photoIDs / delete
//    → AUDIO:      AudioPlaying.previewLooping / stopPreview (the scene's sound)
//    → SETTINGS:   AppSettings.savedWallpapers (bookmarks)
//    → NAVIGATES:  AppCoordinator.completeWallpaperPicker(with:) / dismissSheet()
//

import Foundation
import Observation
import UIKit

@Observable
final class WallpaperPickerViewModel {
    /// The highlighted choice. `nil` = "Default" (only possible when `allowsDefault`).
    private(set) var selection: Wallpaper?
    /// Shows the "Use the default" row (alarm editor) or not (choosing the default itself).
    let allowsDefault: Bool
    /// What "Default" means right now (from Settings), for its preview and name.
    let defaultWallpaper: Wallpaper
    /// The alarm's current sound: what plays with your own photos (they have no sound of their own).
    let currentSound: AlarmSound
    /// The tab on screen.
    var category: WallpaperCategory

    /// The user's photos, newest first, and their decoded images for the grid.
    private(set) var photoIDs: [UUID] = []
    private(set) var photos: [UUID: UIImage] = [:]
    private(set) var isAddingPhoto = false
    private(set) var errorMessage: String?

    // MARK: Scene Player state (#33)

    /// True while the full-screen player is open. → `.fullScreenCover(isPresented:)`
    var isShowingPlayer = false
    /// The wallpapers the player steps through with ⏮ ⏭ (the tab it was opened from).
    private(set) var playlist: [Wallpaper] = []
    private(set) var playerIndex = 0
    /// Is the scene's sound playing right now?
    private(set) var isSoundPlaying = false

    let categories = WallpaperCategory.allCases

    private let store: any WallpaperStoring
    private let audio: any AudioPlaying
    private let settings: AppSettings
    private let coordinator: AppCoordinator

    init(selected: Wallpaper?, allowsDefault: Bool, defaultWallpaper: Wallpaper, currentSound: AlarmSound,
         store: any WallpaperStoring, audio: any AudioPlaying, settings: AppSettings, coordinator: AppCoordinator) {
        self.selection = selected
        self.allowsDefault = allowsDefault
        self.defaultWallpaper = defaultWallpaper
        self.currentSound = currentSound
        self.store = store
        self.audio = audio
        self.settings = settings
        self.coordinator = coordinator
        // Open on the tab of the current choice.
        switch selected ?? defaultWallpaper {
        case .live(let style): category = style.category
        case .photo: category = .myPhotos
        case .surprise: category = .world
        }
    }

    // MARK: - Reading

    func isSelected(_ wallpaper: Wallpaper?) -> Bool { selection == wallpaper }

    /// The photo for a `.photo` wallpaper, if loaded.
    func photo(for wallpaper: Wallpaper?) -> UIImage? {
        if case .photo(let id) = wallpaper { return photos[id] }
        return nil
    }

    var defaultTitle: String { "Default · \(defaultWallpaper.title)" }

    /// The cards in the current tab.
    var wallpapersInCategory: [Wallpaper] { wallpapers(in: category) }

    func wallpapers(in category: WallpaperCategory) -> [Wallpaper] {
        switch category {
        case .saved:
            // Bookmarks, skipping ones that no longer exist (a deleted photo, a removed wallpaper).
            return settings.savedWallpapers.compactMap(Wallpaper.init(rawValue:)).filter { wallpaper in
                if case .photo(let id) = wallpaper { return photoIDs.contains(id) }
                return true
            }
        case .myPhotos:
            return photoIDs.map { .photo(id: $0) }
        default:
            return category.liveWallpapers.map { .live($0) }
        }
    }

    /// The sound that plays with a wallpaper: a live scene's own sound, or the alarm's sound for photos.
    func sound(for wallpaper: Wallpaper) -> AlarmSound {
        switch wallpaper.resolved() {
        case .live(let style): style.signatureSound
        default: currentSound
        }
    }

    /// Does this wallpaper have its own sound? (Photos don't.)
    func hasSignatureSound(_ wallpaper: Wallpaper) -> Bool {
        if case .live = wallpaper.resolved() { return true }
        return false
    }

    func isSaved(_ wallpaper: Wallpaper) -> Bool {
        settings.savedWallpapers.contains(wallpaper.rawValue)
    }

    // MARK: - Loading photos

    /// ← CALLED BY: the View's `.task` (once, when the sheet opens)
    func loadPhotos() async {
        photoIDs = store.photoIDs()
        for id in photoIDs where photos[id] == nil {
            photos[id] = await store.image(for: id)            // → decoded off the main thread
        }
    }

    // MARK: - Scene Player (#33)

    /// What the player shows right now.
    var playing: Wallpaper? {
        playlist.indices.contains(playerIndex) ? playlist[playerIndex] : nil
    }

    /// "3 / 11" under the controls.
    var playerPosition: String { "\(playerIndex + 1) / \(playlist.count)" }

    /// Tap a card: open the player on it, with the rest of its tab as the playlist.
    func openPlayer(_ wallpaper: Wallpaper) {
        Trace.log(.wallpaper, "openPlayer(\(wallpaper.rawValue)) → full screen + \(sound(for: wallpaper).rawValue)")
        var list = wallpapersInCategory
        if !list.contains(wallpaper) { list = [wallpaper] }
        playlist = list
        playerIndex = list.firstIndex(of: wallpaper) ?? 0
        isShowingPlayer = true
        playCurrentSound()
    }

    /// ⏭ or swipe left. Wraps around at the end.
    func next() { step(by: 1) }

    /// ⏮ or swipe right.
    func previous() { step(by: -1) }

    private func step(by delta: Int) {
        guard !playlist.isEmpty else { return }
        playerIndex = (playerIndex + delta + playlist.count) % playlist.count
        if isSoundPlaying { playCurrentSound() }              // keep the music going on the new scene
    }

    /// ▶︎ / ⏸
    func togglePlay() {
        if isSoundPlaying {
            audio.stopPreview()
            isSoundPlaying = false
        } else {
            playCurrentSound()
        }
    }

    /// ♥ Saves (or un-saves) the current scene in the "Saved" tab.
    func toggleSaved() {
        guard let wallpaper = playing else { return }
        if let index = settings.savedWallpapers.firstIndex(of: wallpaper.rawValue) {
            settings.savedWallpapers.remove(at: index)
        } else {
            settings.savedWallpapers.insert(wallpaper.rawValue, at: 0)
        }
    }

    /// "Use wallpaper + sound" (`withSound: true`) or "Wallpaper only".
    ///
    /// WHY the short wait: closing the full-screen player and the sheet in the same instant makes
    /// SwiftUI skip an animation (or complain). The player closes first, then the sheet.
    func use(withSound: Bool) async {
        Trace.log(.wallpaper, "use(withSound: \(withSound)) → close player, then coordinator.completeWallpaperPicker")
        guard let wallpaper = playing else { return }
        selection = wallpaper
        let sound: AlarmSound? = withSound && hasSignatureSound(wallpaper) ? sound(for: wallpaper) : nil
        closePlayer()
        try? await Task.sleep(for: .milliseconds(350))
        coordinator.completeWallpaperPicker(with: WallpaperChoice(wallpaper: wallpaper, sound: sound))   // → editor / Settings
    }

    func closePlayer() {
        audio.stopPreview()
        isSoundPlaying = false
        isShowingPlayer = false
    }

    private func playCurrentSound() {
        guard let wallpaper = playing else { return }
        audio.previewLooping(sound(for: wallpaper))           // → AudioService (loops until stopped)
        isSoundPlaying = true
    }

    // MARK: - Picker actions

    /// Tap the Default or Surprise row: choose without previewing.
    func choose(_ wallpaper: Wallpaper?) {
        selection = wallpaper
    }

    /// ← CALLED BY: the photo library after the user picked a picture (the View loads its Data).
    func addPhoto(_ data: Data) async {
        isAddingPhoto = true
        defer { isAddingPhoto = false }
        do {
            let id = try await store.add(data)                   // → resized + saved in the background
            photoIDs.insert(id, at: 0)
            photos[id] = await store.image(for: id)
            selection = .photo(id: id)
            openPlayer(.photo(id: id))                           // show it full screen right away
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// ← CALLED BY: a photo's context menu "Delete"
    func deletePhoto(_ id: UUID) {
        store.delete(id)
        photoIDs.removeAll { $0 == id }
        photos[id] = nil
        settings.savedWallpapers.removeAll { $0 == Wallpaper.photo(id: id).rawValue }
        // WHY: alarms that used this photo fall back to the default automatically (WallpaperView
        // draws a live wallpaper when a photo is missing), so nothing breaks.
        if selection == .photo(id: id) { selection = allowsDefault ? nil : .standard }
    }

    func dismissError() { errorMessage = nil }

    func done() {
        audio.stopPreview()
        coordinator.completeWallpaperPicker(with: WallpaperChoice(wallpaper: selection, sound: nil))
    }

    func cancel() {
        audio.stopPreview()
        coordinator.dismissSheet()
    }

    /// ← CALLED BY: the sheet disappearing (also when swiped down): never leave a sound playing.
    func stopSound() {
        audio.stopPreview()
        isSoundPlaying = false
    }
}
