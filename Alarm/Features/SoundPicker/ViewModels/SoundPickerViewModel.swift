//
//  SoundPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel
//  WHAT:  The brain of the Sound Picker (Screen #13): which sound is selected, which one
//         is previewing, and handing the choice back to the editor.
//  DATA:  none stored. The choice travels back through AppCoordinator to the editor's draft.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .soundPicker(selected:))
//    ← OPENED BY:  AlarmEditorViewModel.chooseSound() → AppCoordinator.presentSoundPicker
//    → AUDIO:      AudioPlaying.preview / stopPreview  (AudioService → AVAudioPlayer)
//    → RESULT:     AppCoordinator.completeSoundPicker(with:) → editor's draft.soundName
//    → CANCEL:     AppCoordinator.dismissSheet()
//

import Foundation
import Observation

@Observable
final class SoundPickerViewModel {
    /// The highlighted sound (not saved anywhere until the editor's Save).
    private(set) var selected: AlarmSound
    /// The sound currently playing a preview, for the "speaker" animation. `nil` = silent.
    private(set) var previewing: AlarmSound?

    /// Sections of the list, in order.
    let categories = AlarmSound.Category.allCases

    private let audio: any AudioPlaying
    private let coordinator: AppCoordinator
    private var stopPreviewTask: Task<Void, Never>?

    init(selected: AlarmSound, audio: any AudioPlaying, coordinator: AppCoordinator) {
        self.selected = selected
        self.audio = audio
        self.coordinator = coordinator
    }

    /// Tap a row: select it and play a short preview.
    /// ← CALLED BY: a row in SoundPickerView
    func select(_ sound: AlarmSound) {
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
        coordinator.completeSoundPicker(with: selected)   // → editor's onPick → draft.soundName
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
}
