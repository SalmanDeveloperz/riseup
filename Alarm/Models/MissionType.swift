//
//  MissionType.swift
//  RiseUp
//
//  LAYER: Model (plain value types)
//  WHAT:  The kinds of wake-up missions and their difficulty levels.
//  USED BY: MissionConfig (stored as raw values), Mission Picker & mission screens (Phase 2–3).
//

import Foundation

/// Every mission a user can attach to an alarm.
///
/// LEARN: `String` raw values ("math", "shake") are what actually get SAVED in the
/// database. NEVER rename a raw value after release: existing users' saved missions
/// would no longer match. Renaming the Swift case name is fine.
nonisolated enum MissionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case math
    case typing
    case memory
    case shake
    case steps
    case squat
    case photo
    case barcode

    var id: String { rawValue }

    /// Name shown in the UI.
    var title: String {
        switch self {
        case .math: "Math"
        case .typing: "Typing"
        case .memory: "Memory"
        case .shake: "Shake"
        case .steps: "Steps"
        case .squat: "Squats"
        case .photo: "Photo"
        case .barcode: "QR / Barcode"
        }
    }

    /// SF Symbol icon name.
    var systemImage: String {
        switch self {
        case .math: "plus.forwardslash.minus"
        case .typing: "keyboard"
        case .memory: "square.grid.3x3.fill"
        case .shake: "iphone.radiowaves.left.and.right"
        case .steps: "figure.walk"
        case .squat: "figure.strengthtraining.functional"
        case .photo: "camera.fill"
        case .barcode: "qrcode.viewfinder"
        }
    }
}

/// How hard a mission is. Stored as an `Int` raw value.
nonisolated enum MissionDifficulty: Int, CaseIterable, Codable, Identifiable, Sendable {
    case veryEasy = 0
    case easy = 1
    case normal = 2
    case hard = 3
    case veryHard = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .veryEasy: "Very easy"
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        case .veryHard: "Very hard"
        }
    }
}
