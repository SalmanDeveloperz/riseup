//
//  SoundPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The brain of the Sound Picker (Screen #13, + #37): which sound is selected, which one is
//         previewing, the search, and the user's own sounds (add from Files / a video in Photos,
//         rename, delete). Hands the choice back to the editor (or Settings).
//  DATA:  reads the user's sounds from CustomSoundLibrary (its `sounds` is the live list) and
//         reads alarms (only to check whether a sound is in use before deleting it).
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .soundPicker(selected:allowsCustom:))
//    ← OPENED BY:  AlarmEditorViewModel.chooseSound() / SettingsViewModel.chooseDefaultSound()
//                  → AppCoordinator.presentSoundPicker
//    → AUDIO:      AudioPlaying.preview / stopPreview  (AudioService → AVAudioPlayer)
//    → SOUNDS:     CustomSoundStoring.add / rename / delete  (CustomSoundLibrary → SoundClipMaker)
//    → ALARMS:     AlarmRepository.alarms (read only)
//    → RESULT:     AppCoordinator.completeSoundPicker(with:) → editor's draft.sound
//    → CANCEL:     AppCoordinator.dismissSheet()
//

import Foundation
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class SoundPickerViewModel {
    /// The highlighted sound (not saved anywhere until the editor's Save).
    private(set) var selected: SoundChoice
    /// The sound currently playing a preview, for the "speaker" animation. `nil` = silent.
    private(set) var previewing: SoundChoice?
    /// What the user typed in the search bar.
    var searchText = ""
    /// False when choosing Settings' default sound: then only our sounds are offered.
    let allowsCustom: Bool

    // MARK: Adding a sound
    /// True while a sound is being loaded/converted: the "Adding…" row shows and adding is blocked.
    private(set) var isImporting = false
    /// A message for the alert when adding (or deleting) didn't work. `nil` = no alert.
    var alertMessage: String?
    var isShowingFileImporter = false
    var isShowingPhotoPicker = false
    /// The video picked in Photos (the View watches it and calls `addVideo`).
    var pickedVideo: PhotosPickerItem?

    // MARK: Rename / delete
    /// The sound being renamed (the rename alert is up), and the text field's value.
    var renaming: CustomSound?
    var renameText = ""
    /// The sound waiting for "Delete?" confirmation.
    var deleting: CustomSound?

    private let audio: any AudioPlaying
    private let library: any CustomSoundStoring
    private let alarmRepository: AlarmRepository
    private let coordinator: AppCoordinator
    private var stopPreviewTask: Task<Void, Never>?

    /// The file types the Files picker offers: any audio, and videos (their sound is used).
    /// LEARN: a UTType ("Uniform Type Identifier") names a KIND of file. `.audio` covers MP3, M4A,
    /// WAV, AIFF, CAF…; `.movie` covers MOV and MP4.
    static let importableTypes: [UTType] = [.audio, .movie]

    init(selected: SoundChoice, allowsCustom: Bool = true, audio: any AudioPlaying,
         customSounds: any CustomSoundStoring, alarmRepository: AlarmRepository, coordinator: AppCoordinator) {
        self.selected = selected
        self.allowsCustom = allowsCustom
        self.audio = audio
        self.library = customSounds
        self.alarmRepository = alarmRepository
        self.coordinator = coordinator
    }

    // MARK: - What the list shows (search)

    /// The user's sounds that match the search (none when `allowsCustom` is false).
    var visibleCustomSounds: [CustomSound] {
        guard allowsCustom else { return [] }
        return library.sounds.filter { Self.matches(searchText, fields: [$0.name, "my sounds", "your sound"]) }
    }

    /// Our sounds that match the search, grouped by category (empty groups are left out).
    var visibleCategories: [(category: AlarmSound.Category, sounds: [AlarmSound])] {
        AlarmSound.Category.allCases.compactMap { category in
            let sounds = category.sounds.filter {
                Self.matches(searchText, fields: [$0.title, $0.subtitle, category.rawValue])
            }
            return sounds.isEmpty ? nil : (category, sounds)
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Nothing matches the search → the View shows "No results".
    var hasNoResults: Bool { isSearching && visibleCustomSounds.isEmpty && visibleCategories.isEmpty }

    /// Does `query` match? Every word must appear in one of the fields, ignoring case and accents:
    /// "rain" finds Rainforest and Thunderstorm ("Heavy rain…"); "world drum" finds Savanna Drums.
    /// An empty query matches everything.
    ///
    /// LEARN: `localizedStandardContains` is the search Finder uses: "cafe" finds "Café", "BELL" finds "bell".
    nonisolated static func matches(_ query: String, fields: [String]) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        return words.allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
    }

    // MARK: - Choosing

    /// Tap a row: select it and play a short preview.
    /// ← CALLED BY: a row in SoundPickerView, and after adding a sound
    func select(_ sound: SoundChoice) {
        selected = sound
        previewing = sound
        audio.preview(sound)                           // → AudioService plays the file once

        // Previews are 12 s long; stop after 4 s so tapping around isn't overwhelming.
        // TRY: change 4 to 12 to hear each sound in full.
        stopPreviewTask?.cancel()
        stopPreviewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.stopPreview()
        }
    }

    /// ← CALLED BY: "Done"
    func done() {
        stopPreview()
        coordinator.completeSoundPicker(with: selected)   // → editor's onPick → draft.sound
    }

    /// ← CALLED BY: "Cancel"
    func cancel() {
        stopPreview()
        coordinator.dismissSheet()
    }

    /// ← CALLED BY: the view disappearing (also when swiped down)
    func stopPreview() {
        stopPreviewTask?.cancel()
        audio.stopPreview()
        previewing = nil
    }

    // MARK: - Adding a sound (#37)

    /// ← CALLED BY: "Add your own sound" menu → "From Files"
    func chooseFromFiles() {
        stopPreview()
        isShowingFileImporter = true                    // → .fileImporter in the View
    }

    /// ← CALLED BY: "Add your own sound" menu → "Sound of a video"
    func chooseFromPhotos() {
        stopPreview()
        pickedVideo = nil
        isShowingPhotoPicker = true                     // → .photosPicker in the View
    }

    /// ← CALLED BY: `.fileImporter`'s answer.
    func addFile(_ result: Result<URL, any Error>) async {
        switch result {
        case .success(let url):
            await addSound(from: url, suggestedName: url.deletingPathExtension().lastPathComponent)
        case .failure:
            alertMessage = SoundClipMaker.ImportError.unreadable.errorDescription
        }
    }

    /// ← CALLED BY: the View when `pickedVideo` changes (the user picked a video in Photos).
    func addVideo(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        isImporting = true                              // the spinner shows while Photos hands it over
        defer { isImporting = false }
        Trace.log(.audio, "SoundPickerViewModel.addVideo() → load from Photos as a file")
        // LEARN: `loadTransferable` asks Photos for the video. If it's only in iCloud, Photos
        // downloads it first, which is why this can take a moment for big, old videos.
        let movie: PickedMovie?
        do { movie = try await item.loadTransferable(type: PickedMovie.self) } catch { movie = nil }
        guard let movie else {
            alertMessage = SoundClipMaker.ImportError.couldNotLoad.errorDescription
            return
        }
        defer { try? FileManager.default.removeItem(at: movie.url) }      // only OUR temporary copy
        await addSound(from: movie.url, suggestedName: "Video sound", alreadyImporting: true)
    }

    /// Makes the clip, adds it to the library, then selects and plays it.
    /// ← CALLED BY: addFile / addVideo, and tests (with real files)
    func addSound(from url: URL, suggestedName: String, alreadyImporting: Bool = false) async {
        guard alreadyImporting || !isImporting else { return }   // one at a time
        isImporting = true
        defer { if !alreadyImporting { isImporting = false } }
        do {
            let sound = try await library.add(from: url, suggestedName: suggestedName)   // → background work
            searchText = ""                             // so the new sound is visible at the top
            select(.custom(sound))
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription
                ?? SoundClipMaker.ImportError.unreadable.errorDescription
        }
    }

    // MARK: - Rename / delete (#37)

    /// ← CALLED BY: a sound's menu → "Rename"
    func startRename(_ sound: CustomSound) {
        renameText = sound.name
        renaming = sound
    }

    /// ← CALLED BY: the rename alert's "Save"
    func confirmRename() {
        guard let sound = renaming else { return }
        library.rename(sound.id, to: renameText)
        renaming = nil
        refreshSelected(sound.id)                       // the checkmark row shows the new name
    }

    /// How many alarms use this sound (switched on or off).
    func alarmsUsing(_ sound: CustomSound) -> Int {
        alarmRepository.alarms.filter { $0.soundName == sound.fileName }.count
    }

    /// ← CALLED BY: a sound's menu → "Delete"
    /// WHY blocked while in use: an alarm whose sound vanished would ring iOS's tone instead, a
    /// surprise for the user. Choosing another sound for those alarms first keeps it their choice.
    func askToDelete(_ sound: CustomSound) {
        let count = alarmsUsing(sound)
        guard count == 0 else {
            alertMessage = "“\(sound.name)” is the sound of \(count == 1 ? "an alarm" : "\(count) alarms"). "
                + "Choose another sound for \(count == 1 ? "it" : "them") first."
            return
        }
        deleting = sound                                // → confirmation dialog
    }

    /// ← CALLED BY: the confirmation dialog's "Delete"
    func confirmDelete() {
        guard let sound = deleting else { return }
        deleting = nil
        if isPreviewing(.custom(sound)) { stopPreview() }
        library.delete(sound.id)
        // The picker never keeps a deleted sound selected.
        if case .custom(let chosen) = selected, chosen.id == sound.id { selected = .builtIn(.radar) }
    }

    /// After a rename, the selected copy gets the new name too.
    private func refreshSelected(_ id: UUID) {
        guard case .custom(let chosen) = selected, chosen.id == id,
              let fresh = library.sounds.first(where: { $0.id == id }) else { return }
        selected = .custom(fresh)
    }

    /// Is this row the selected one? (Custom sounds compare by id: a rename doesn't unselect them.)
    func isSelected(_ sound: SoundChoice) -> Bool { selected.soundName == sound.soundName }
    func isPreviewing(_ sound: SoundChoice) -> Bool { previewing?.soundName == sound.soundName }
}
