//
//  MissionPickerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screens #9 Mission Picker + #10 Mission Settings, in one sheet)
//  WHAT:  Step 1: choose a mission type. Step 2: difficulty + how many. Optional: "Try it".
//         Then hands the finished MissionDraft back to the editor.
//  DATA:  none stored. The result travels back through AppCoordinator to the editor's draft.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .missionPicker(editing:))
//    ← OPENED BY:  AlarmEditorViewModel.addMission() / editMission(_:)
//                  → AppCoordinator.presentMissionPicker(editing:onPick:)
//    → RESULT:     AppCoordinator.completeMissionPicker(with:) → editor's draft.missions
//    → CANCEL:     AppCoordinator.dismissSheet()
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

    let shakeDetector: any ShakeDetecting
    private let coordinator: AppCoordinator

    init(editing: MissionDraft?, shakeDetector: any ShakeDetecting, coordinator: AppCoordinator) {
        self.draft = editing
        self.isEditing = editing != nil
        self.shakeDetector = shakeDetector
        self.coordinator = coordinator
        // Editing jumps straight to the settings step (Back still shows the type grid).
        if editing != nil { path = [.settings] }
        refreshSample()
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
        }
        refreshSample()
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
        if d.type == .shake { refreshSample() }   // the shake example mentions the count
    }

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
        default: draft.type.pitch
        }
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
        guard let draft else { return }
        coordinator.completeMissionPicker(with: draft)   // → editor's onPick → draft.missions
    }

    func cancel() {
        coordinator.dismissSheet()
    }
}
