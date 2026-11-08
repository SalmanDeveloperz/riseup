//
//  Mood.swift
//  RiseUp
//
//  LAYER: Model (plain value type)
//  WHAT:  How the user felt after waking up (Screen #17, Morning check-in).
//  DATA:  stored as `WakeRecord.moodRawValue` (1…5). The field existed since SchemaV2,
//         waiting for this feature, so no database change was needed.
//
//  CONNECTIONS:
//    ← SET BY:  SuccessView (right after waking) and MorningView ("How do you feel?" later)
//    ← READ BY: RecordsView (calendar), StatsView (mood chart)
//
//  LEARN: raw values 1…5 are SAVED in the database. Never change them after release;
//  renaming the Swift cases or the emoji is fine.
//

import Foundation

nonisolated enum Mood: Int, CaseIterable, Identifiable, Sendable {
    case awful = 1
    case meh = 2
    case okay = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }

    /// TRY: swap the emoji for ones you like better.
    var emoji: String {
        switch self {
        case .awful: "😫"
        case .meh: "😕"
        case .okay: "😐"
        case .good: "🙂"
        case .great: "🤩"
        }
    }

    var title: String {
        switch self {
        case .awful: "Awful"
        case .meh: "Meh"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }
}
