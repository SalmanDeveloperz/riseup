//
//  MissionDraft.swift
//  RiseUp
//
//  LAYER: ViewModel (editable value copy of one mission's settings)
//  WHAT:  "Math · Hard · 5 problems" as a plain struct, plus the allowed ranges per mission.
//  DATA:  a COPY of a MissionConfig (including its payloads: the registered photo's
//         fingerprint or the registered barcode). Becomes a real MissionConfig only when
//         the alarm is saved.
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
    /// Barcode mission: the code's text ("4006381333931"), registered in the Mission Picker.
    var textPayload: String? = nil
    /// Photo mission: the registered photo (fingerprint + thumbnail), see PhotoMissionPayload.
    var dataPayload: Data? = nil

    /// Sensible starting settings when the user picks a mission type.
    static func defaults(for type: MissionType) -> MissionDraft {
        MissionDraft(type: type, difficulty: .normal, repetitions: type.defaultRepetitions)
    }

    /// "Normal · 3 problems"
    var summary: String {
        if type == .photo { return dataPayload == nil ? "No photo yet" : "Photo registered" }
        if type == .barcode { return textPayload == nil ? "No code yet" : "Code registered" }
        if type.usesDifficulty {
            return "\(difficulty.title) · \(repetitions) \(type.repetitionUnit(repetitions))"
        }
        return "\(repetitions) \(type.repetitionUnit(repetitions))"
    }

    /// Photo and barcode missions must be set up first (take the photo / scan the code).
    var needsRegistration: Bool {
        type == .photo || type == .barcode
    }

    /// False until a photo/barcode mission has its registration. "Add mission" stays disabled.
    var isReadyToSave: Bool {
        switch type {
        case .photo: dataPayload != nil
        case .barcode: !(textPayload ?? "").isEmpty
        default: true
        }
    }
}

// MARK: - MissionConfig → MissionDraft

// LEARN: this extension is NOT `nonisolated`: it reads a SwiftData @Model (MissionConfig),
// and in this project @Model objects belong to the main actor. One place converts rows to
// drafts, so the editor and the ringing screen can never forget a field (like a payload).
extension MissionDraft {
    /// Copies a saved mission (database row) into an editable/plain value.
    /// ← USED BY: AlarmEditorViewModel (fill the draft), RingingViewModel (missions to run)
    init(_ config: MissionConfig) {
        self.init(
            id: config.id,
            type: config.type,
            difficulty: config.difficulty,
            repetitions: config.repetitions,
            textPayload: config.textPayload,
            dataPayload: config.dataPayload
        )
    }
}

// MARK: - Per-mission rules

// LEARN: `nonisolated extension`: in this project, code defaults to the main actor, and
// that default applies to EACH extension separately, even if the type itself (MissionType)
// is `nonisolated`. Without the keyword, MissionDraft (nonisolated) couldn't call these.
nonisolated extension MissionType {
    /// Missions the picker offers. Since Phase 3 that's all of them.
    /// TRY: return `false` for `.squat` and open the Mission Picker: the card greys out.
    var isAvailable: Bool {
        switch self {
        case .math, .typing, .shake, .memory, .steps, .squat, .photo, .barcode: true
        }
    }

    /// Missions that need a sensor or the camera. If it's missing or not allowed on this
    /// iPhone, the mission falls back to Math (see MissionView), so nobody gets stuck.
    var needsHardware: Bool {
        switch self {
        case .shake, .steps, .squat, .photo, .barcode: true
        case .math, .typing, .memory: false
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

    /// Seconds without any tap/step/shake before the alarm sound comes back during this mission.
    ///
    /// WHY longer for some: walking to the bathroom to photograph the sink, or to the kitchen
    /// to scan a code, takes a while, and the user isn't touching the screen on the way.
    /// TRY: set `.photo` to 30 and see how soon the alarm comes back while you walk.
    var idleSecondsAllowed: TimeInterval {
        switch self {
        case .photo, .barcode: 90
        case .steps: 45
        case .math, .typing, .memory, .shake, .squat: 15
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
