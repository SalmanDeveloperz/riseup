//
//  TypingPhrases.swift
//  RiseUp
//
//  LAYER: Pure logic (no UI)
//  WHAT:  The phrases for the Typing mission, and the rule for "did they type it right?".
//  DATA:  none (phrases are written in code, all original RiseUp text).
//
//  CONNECTIONS:
//    ← USED BY: TypingMissionViewModel, MissionPickerView (sample phrase)
//
//  TRY: add your own phrases (in your language too). Longer phrases = harder.
//

import Foundation

nonisolated enum TypingPhrases {

    /// Phrases grouped by length. Difficulty picks the group.
    static let short = [
        "Rise and shine",
        "I am wide awake",
        "Today is my day",
        "Up and at it",
        "Good morning world",
        "Feet on the floor",
        "Coffee is calling",
        "No more snoozing",
    ]

    static let medium = [
        "I choose to start this day with energy",
        "Small steps every morning add up to big change",
        "My goals are waiting and I am ready",
        "I get up early because my dreams matter",
        "A fresh day means a fresh chance to win",
        "I am proud of myself for getting out of bed",
    ]

    static let long = [
        "Every single morning is a brand new opportunity to become a better version of myself",
        "Discipline is choosing what I want most over what I want right now, starting today",
        "The bed will still be there tonight, but this morning will never come back again",
        "I am awake, I am focused, and I am going to make today count for something real",
    ]

    /// `count` different phrases for `difficulty` (repeats only if asking for more than exist).
    static func pick(_ count: Int, difficulty: MissionDifficulty) -> [String] {
        let pool: [String] = switch difficulty {
        case .veryEasy, .easy: short
        case .normal: medium
        case .hard, .veryHard: long
        }
        var result: [String] = []
        var bag = pool.shuffled()
        while result.count < count {
            if bag.isEmpty { bag = pool.shuffled() }
            result.append(bag.removeLast())
        }
        return result
    }

    /// True when `typed` matches `phrase`, ignoring upper/lower case, extra spaces and
    /// a missing final full stop. Every other character must be exact.
    ///
    /// WHY forgiving about case and spaces: the point is to make the brain work, not to
    /// fight the keyboard's auto-capitalisation.
    static func matches(_ typed: String, phrase: String) -> Bool {
        normalize(typed) == normalize(phrase)
    }

    /// How many leading characters are correct, used to colour the phrase green as you type.
    static func correctPrefixLength(_ typed: String, phrase: String) -> Int {
        let a = Array(typed.lowercased()), b = Array(phrase.lowercased())
        var count = 0
        while count < a.count, count < b.count, a[count] == b[count] { count += 1 }
        return count
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
