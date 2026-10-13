//
//  MissionPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screens #9 Mission Picker + #10 Mission Settings + #11/#12 registration)
//  WHAT:  Step 1: choose a mission type. Step 2: difficulty + how many, or, for Photo and
//         Barcode missions, REGISTER the spot/code. Optional: "Try it". Then hands the
//         finished MissionDraft back to the editor.
//  DATA:  none stored. The result (with its payload) travels back through AppCoordinator
//         to the editor's draft, and is saved only when the alarm is saved.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .missionPicker(editing:))
//    ← OPENED BY:  AlarmEditorViewModel.addMission() / editMission(_:)
//                  → AppCoordinator.presentMissionPicker(editing:onPick:)
//    → RESULT:     AppCoordinator.completeMissionPicker(with:) → editor's draft.missions
//    → CANCEL:     AppCoordinator.dismissSheet()
//    → USES:       MissionServices.photoMatcher (photo fingerprint), CameraAccess (permission)
//
//  LEARN: a "child coordinator" inside a sheet
//  ───────────────────────────────────────────
//  The app's AppCoordinator decides WHICH sheet is open. The steps INSIDE this sheet
//  (type → settings → practice) are private to this flow, so this ViewModel owns its own
//  small navigation `path`. Big coordinator for app-level routes; small local path for a
//  self-contained flow. Neither needs to know the other's details.
//

import Foundation
import Observation
import UIKit

@Observable
final class MissionPickerViewModel {
    /// Screens pushed inside the sheet, on top of the type grid.
    enum Step: Hashable {
        case settings
        case practice
    }

    /// Bound to the sheet's NavigationStack. Empty = the type grid is showing.
    var path: [Step] = []

    /// The mission being set up. `nil` until a type is chosen.
    private(set) var draft: MissionDraft?

    /// True when changing an existing mission (the button says "Save" instead of "Add").
    let isEditing: Bool

    /// Flips after a successful practice run, for a "Nice! You're ready" message.
    private(set) var practiceSuccessCount = 0

    /// All mission types, available ones first. → MissionType.isAvailable
    let types: [MissionType] = MissionType.allCases.sorted { $0.isAvailable && !$1.isAvailable }

    let services: MissionServices
    private let coordinator: AppCoordinator

    // MARK: - Registration state (Photo / Barcode)

    /// Bound to the camera (photo registration).
    var isShowingCamera = false
    /// Bound to the code scanner (barcode registration).
    var isShowingScanner = false
    /// True while Vision computes the photo's fingerprint.
    private(set) var isRegistering = false
    /// Non-nil → the View shows an alert (e.g. camera not allowed).
    private(set) var registrationError: String?
    /// True when the alert should offer "Open Settings" (only for permission problems).
    private(set) var registrationErrorOffersSettings = false
    /// The registered photo, small, for the settings card.
    private(set) var registeredThumbnail: UIImage?

    init(editing: MissionDraft?, services: MissionServices, coordinator: AppCoordinator) {
        self.draft = editing
        self.isEditing = editing != nil
        self.services = services
        self.coordinator = coordinator
        // Editing jumps straight to the settings step (Back still shows the type grid).
        if editing != nil { path = [.settings] }
        refreshSample()
        refreshThumbnail()
    }

    // MARK: - Step 1: type

    /// ← CALLED BY: a card in the type grid
    func choose(_ type: MissionType) {
        guard type.isAvailable else { return }
        if var existing = draft, existing.type == type {
            existing.repetitions = min(max(existing.repetitions, type.repetitionRange.lowerBound), type.repetitionRange.upperBound)
            draft = existing
        } else {
            var fresh = MissionDraft.defaults(for: type)
            if let existing = draft { fresh.id = existing.id }   // editing: keep the same identity
            draft = fresh
            practiceSuccessCount = 0          // "Nice!" belonged to the previous mission type
        }
        refreshSample()
        refreshThumbnail()
        if type == .photo {
            CameraAccess.prepareCamera()      // → camera gets ready in the background (fast "Take photo")
        }
        path.append(.settings)
    }

    // MARK: - Step 2: settings

    func setDifficulty(_ difficulty: MissionDifficulty) {
        draft?.difficulty = difficulty
        refreshSample()
    }

    /// ← CALLED BY: − / + buttons. Stays inside the mission's allowed range.
    func adjustRepetitions(by direction: Int) {
        guard var d = draft else { return }
        let range = d.type.repetitionRange
        d.repetitions = min(range.upperBound, max(range.lowerBound, d.repetitions + direction * d.type.repetitionStep))
        draft = d
        refreshSample()                     // several examples mention the count
    }

    /// Photo/Barcode missions have exactly one photo/scan, so there's nothing to count.
    var showsCount: Bool {
        guard let draft else { return false }
        return draft.type.repetitionRange.count > 1
    }

    /// "Add mission" is disabled until a photo/barcode mission has its registration.
    var canSave: Bool { draft?.isReadyToSave ?? false }

    /// An example of what the mission will look like at the chosen settings.
    ///
    /// WHY stored (and not computed): a computed example would be re-randomised on EVERY
    /// redraw, so tapping "+" would also change the example problem. Now it only changes
    /// when the type, difficulty or count changes (`refreshSample()`).
    private(set) var sampleText = ""

    private func refreshSample() {
        guard let draft else { sampleText = ""; return }
        sampleText = switch draft.type {
        case .math: MathProblemGenerator.make(draft.difficulty).text + " = ?"
        case .typing: "“" + (TypingPhrases.pick(1, difficulty: draft.difficulty).first ?? "") + "”"
        case .shake: "Shake \(draft.repetitions) times, \(draft.difficulty.title.lowercased()) strength"
        case .memory: Self.memoryExample(draft)
        case .steps: "Walk \(draft.repetitions) steps"
        case .squat: "Do \(draft.repetitions) squats"
        case .photo: "Photograph the same spot to stop the alarm"
        case .barcode: "Scan the same code to stop the alarm"
        }
    }

    /// "Remember 5 of 16 tiles · 2 rounds"
    private static func memoryExample(_ draft: MissionDraft) -> String {
        let level = MemoryPatternGenerator.level(for: draft.difficulty)
        return "Remember \(level.litTiles) of \(level.gridSize * level.gridSize) tiles"
    }

    // MARK: - Registration: Photo (Screen #11)

    /// ← CALLED BY: "Take photo" / "Retake"
    func takePhoto() async {
        if CameraAccess.usesRealCamera {
            guard await CameraAccess.requestIfNeeded() else {
                showError("Camera access is off. Turn it on in Settings → RiseUp → Camera to use the Photo mission.", offersSettings: true)
                return
            }
        }
        isShowingCamera = true                    // → PhotoCapture (camera, or library in the Simulator)
    }

    /// ← CALLED BY: PhotoCapture when a photo was taken
    func registerPhoto(_ image: UIImage) async {
        guard draft?.type == .photo else { return }
        isRegistering = true
        defer { isRegistering = false }
        do {
            // → resized on a background thread, so the "Saving…" state shows right away
            guard let jpeg = await CameraAccess.makeJPEG(from: image),
                  let thumbnail = await CameraAccess.makeJPEG(from: image, maxSide: 320, quality: 0.7) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let fingerprint = try await services.photoMatcher.fingerprint(of: jpeg)   // → Vision
            let payload = PhotoMissionPayload(fingerprint: fingerprint, thumbnail: thumbnail)
            draft?.dataPayload = try payload.encoded()
            refreshThumbnail()
        } catch {
            // WHY no technical details here: "espresso context" means nothing to a user.
            // The real error still goes to Xcode's console for us.
            print("Photo registration failed:", error)
            showError("Couldn't read that photo. Please try again with a clear, well-lit photo.", offersSettings: false)
        }
    }

    // MARK: - Registration: Barcode (Screen #12)

    /// ← CALLED BY: "Scan a code" / "Scan again"
    func scanCode() async {
        if CameraAccess.usesRealCamera {
            guard await CameraAccess.requestIfNeeded() else {
                showError("Camera access is off. Turn it on in Settings → RiseUp → Camera to use the Barcode mission.", offersSettings: true)
                return
            }
            guard BarcodeScanScreen.canScan else {
                showError("This iPhone can't scan codes with the camera.", offersSettings: false)
                return
            }
        }
        isShowingScanner = true                   // → BarcodeScanScreen
    }

    /// ← CALLED BY: BarcodeScanScreen when a code was read
    func registerCode(_ code: String) {
        isShowingScanner = false
        guard draft?.type == .barcode, !code.isEmpty else { return }
        draft?.textPayload = code
    }

    func dismissRegistrationError() {
        registrationError = nil
        registrationErrorOffersSettings = false
    }

    private func showError(_ message: String, offersSettings: Bool) {
        registrationError = message
        registrationErrorOffersSettings = offersSettings
    }

    private func refreshThumbnail() {
        registeredThumbnail = PhotoMissionPayload.decode(draft?.dataPayload).flatMap { UIImage(data: $0.thumbnail) }
    }

    // MARK: - Practice

    /// ← CALLED BY: "Try it"
    func startPractice() {
        path.append(.practice)
    }

    /// ← CALLED BY: the practice mission's onComplete
    func practiceFinished() {
        practiceSuccessCount += 1
        if path.last == .practice { path.removeLast() }
    }

    // MARK: - Finish

    /// ← CALLED BY: "Add mission" / "Save"
    func save() {
        guard let draft, draft.isReadyToSave else { return }
        coordinator.completeMissionPicker(with: draft)   // → editor's onPick → draft.missions
    }

    func cancel() {
        coordinator.dismissSheet()
    }
}
