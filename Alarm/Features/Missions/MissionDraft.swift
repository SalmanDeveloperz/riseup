//
//  MissionDraft.swift
//  RiseUp
//
//  LAYER: ViewModel (editable value copy of one mission's settings)
//  WHAT:  "Math · Hard · 5 problems" as a plain struct, plus the allowed ranges per mission.
//  DATA:  a COPY of a MissionConfig. Becomes a real MissionConfig only when the alarm is saved.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionPickerViewModel (new mission), AlarmEditorViewModel (from saved MissionConfigs)
//    ← CARRIED BY: SheetRoute.missionPicker(editing:) and AppCoordinator's mission callback
//    → STORED BY:  AlarmEditorViewModel.save() → MissionConfig rows
//    → USED BY:    RingingViewModel (which mission screens to show, how hard)
//
//  LEARN: same idea as AlarmDraft: edit a value, save it in one step at the end.
//

import Foundation

nonisolated struct MissionDraft: Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var type: MissionType
    var difficulty: MissionDifficulty
    /// Problems / phrases / shakes, depending on `type`.
    var repetitions: Int

    /// Sensible starting settings when the user picks a mission type.
    static func defaults(for type: MissionType) -> MissionDraft {
        MissionDraft(type: type, difficulty: .normal, repetitions: type.defaultRepetitions)
    }

    /// "Normal · 3 problems"
    var summary: String {
        if type.usesDifficulty {
            return "\(difficulty.title) · \(repetitions) \(type.repetitionUnit(repetitions))"
        }
        return "\(repetitions) \(type.repetitionUnit(repetitions))"
    }
}

// MARK: - Per-mission rules

// LEARN: `nonisolated extension`: in this project, code defaults to the main actor, and
// that default applies to EACH extension separately, even if the type itself (MissionType)
// is `nonisolated`. Without the keyword, MissionDraft (nonisolated) couldn't call these.
nonisolated extension MissionType {
    /// Missions built so far. The others show as "coming soon" in the picker (Phase 3).
    var isAvailable: Bool {
        switch self {
        case .math, .typing, .shake: true
        case .memory, .steps, .squat, .photo, .barcode: false
        }
    }

    /// One-line description in the picker.
    var pitch: String {
        switch self {
        case .math: "Solve problems to prove your brain is on"
        case .typing: "Type a motivating phrase without mistakes"
        case .memory: "Remember the pattern of lit tiles"
        case .shake: "Shake your phone until the counter hits zero"
        case .steps: "Walk a number of steps"
        case .squat: "Do squats holding your phone"
        case .photo: "Photograph a place far from your bed"
        case .barcode: "Scan a code in another room"
        }
    }

    /// Whether "difficulty" means anything for this mission.
    var usesDifficulty: Bool {
        switch self {
        case .math, .typing, .memory, .shake: true
        case .steps, .squat, .photo, .barcode: false
        }
    }

    /// Allowed "how many" values (shown as a stepper).
    /// TRY: change math's range to `1...20` and open Math's settings.
    var repetitionRange: ClosedRange<Int> {
        switch self {
        case .math: 1...10
        case .typing: 1...5
        case .shake: 10...300
        case .memory: 1...5
        case .steps: 10...200
        case .squat: 5...50
        case .photo, .barcode: 1...1
        }
    }

    /// How much one stepper tap changes the count.
    var repetitionStep: Int {
        switch self {
        case .shake: 10
        case .steps: 10
        case .squat: 5
        default: 1
        }
    }

    var defaultRepetitions: Int {
        switch self {
        case .math: 3
        case .typing: 2
        case .shake: 30
        case .memory: 2
        case .steps: 30
        case .squat: 10
        case .photo, .barcode: 1
        }
    }

    /// "problem" / "problems", "phrase", "shake"…
    func repetitionUnit(_ count: Int) -> String {
        let singular: String = switch self {
        case .math: "problem"
        case .typing: "phrase"
        case .shake: "shake"
        case .memory: "round"
        case .steps: "step"
        case .squat: "squat"
        case .photo: "photo"
        case .barcode: "scan"
        }
        return count == 1 ? singular : singular + "s"
    }
}
