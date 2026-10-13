//
//  WallpaperPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #32 Wallpaper Picker, a sheet)
//  WHAT:  Categories of live wallpapers, "Surprise me", the user's own photos (add / delete),
//         a full-screen "Try it" preview, and handing the choice back to whoever opened it.
//  DATA:  reads/writes photo files through WallpaperStore. Doesn't touch the database: the
//         editor (or Settings) saves the choice.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .wallpaperPicker)
//    ← OPENED BY:  AlarmEditorViewModel.chooseWallpaper(), SettingsViewModel.chooseDefaultWallpaper()
//    → STORE:      WallpaperStoring.add / image / photoIDs / delete
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
    /// The tab on screen.
    var category: WallpaperCategory

    /// The user's photos, newest first, and their decoded images for the grid.
    private(set) var photoIDs: [UUID] = []
    private(set) var photos: [UUID: UIImage] = [:]
    private(set) var isAddingPhoto = false
    private(set) var errorMessage: String?

    /// The wallpaper shown full screen in "Try it" (nil = closed). → `.fullScreenCover(item:)`
    var previewing: Wallpaper?

    let categories = WallpaperCategory.allCases

    private let store: any WallpaperStoring
    private let coordinator: AppCoordinator

    init(selected: Wallpaper?, allowsDefault: Bool, defaultWallpaper: Wallpaper,
         store: any WallpaperStoring, coordinator: AppCoordinator) {
        self.selection = selected
        self.allowsDefault = allowsDefault
        self.defaultWallpaper = defaultWallpaper
        self.store = store
        self.coordinator = coordinator
        // Open on the tab of the current choice.
        switch selected ?? defaultWallpaper {
        case .live(let style): category = style.category
        case .photo: category = .myPhotos
        case .surprise: category = .sunrise
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

    // MARK: - Loading photos

    /// ← CALLED BY: the View's `.task` (once, when the sheet opens)
    func loadPhotos() async {
        photoIDs = store.photoIDs()
        for id in photoIDs where photos[id] == nil {
            photos[id] = await store.image(for: id)            // → decoded off the main thread
        }
    }

    // MARK: - Actions

    /// Tap a card: open the full-screen preview.
    func openPreview(_ wallpaper: Wallpaper) {
        previewing = wallpaper
    }

    /// "Use this wallpaper" in the preview: choose it and close everything.
    ///
    /// WHY the short wait: closing the full-screen preview and the sheet in the same instant makes
    /// SwiftUI skip an animation (or complain). The preview closes first, then the sheet.
    func use(_ wallpaper: Wallpaper?) async {
        selection = wallpaper
        previewing = nil
        try? await Task.sleep(for: .milliseconds(350))
        coordinator.completeWallpaperPicker(with: wallpaper)    // → editor / Settings saves it
    }

    /// Tap the Default or Surprise row: choose without previewing.
    func choose(_ wallpaper: Wallpaper?) {
        selection = wallpaper
    }

    /// ← CALLED BY: the PhotosPicker after the user picked a picture (the View loads its Data).
    func addPhoto(_ data: Data) async {
        isAddingPhoto = true
        defer { isAddingPhoto = false }
        do {
            let id = try await store.add(data)                   // → resized + saved in the background
            photoIDs.insert(id, at: 0)
            photos[id] = await store.image(for: id)
            selection = .photo(id: id)
            previewing = .photo(id: id)                          // show it full screen right away
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// ← CALLED BY: a photo's context menu "Delete"
    func deletePhoto(_ id: UUID) {
        store.delete(id)
        photoIDs.removeAll { $0 == id }
        photos[id] = nil
        // WHY: alarms that used this photo fall back to the default automatically (WallpaperView
        // draws a live wallpaper when a photo is missing), so nothing breaks.
        if selection == .photo(id: id) { selection = allowsDefault ? nil : .standard }
    }

    func dismissError() { errorMessage = nil }

    func done() {
        coordinator.completeWallpaperPicker(with: selection)
    }

    func cancel() {
        coordinator.dismissSheet()
    }
}
