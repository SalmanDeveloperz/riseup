//
//  TypingMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15b: Typing)
//  WHAT:  Shows a phrase; the user types it; when it matches, the next one appears.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView
//    → onInteraction / onComplete: same contract as every mission (see MathMissionViewModel)
//    → USES: TypingPhrases (phrases + matching rules)
//

import Foundation
import Observation

@Observable
final class TypingMissionViewModel {
    private let phrases: [String]
    private(set) var index = 0
    private(set) var solvedCount = 0

    /// The text field's content. Every change is checked immediately.
    /// LEARN: `didSet` runs right after the property changes, ideal for "react to typing".
    var typed = "" {
        didSet { onInteraction(); checkMatch() }
    }

    var total: Int { phrases.count }
    var phrase: String { phrases[min(index, phrases.count - 1)] }

    /// How many characters at the start of the phrase are already typed correctly.
    var correctCount: Int { TypingPhrases.correctPrefixLength(typed, phrase: phrase) }

    private let onInteraction: () -> Void
    private let onComplete: () -> Void

    init(mission: MissionDraft, onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.phrases = TypingPhrases.pick(mission.repetitions, difficulty: mission.difficulty)
        self.onInteraction = onInteraction
        self.onComplete = onComplete
    }

    private func checkMatch() {
        guard TypingPhrases.matches(typed, phrase: phrase) else { return }
        solvedCount += 1
        if solvedCount >= phrases.count {
            onComplete()                                 // → RingingViewModel.missionFinished()
        } else {
            index += 1
            typed = ""
        }
    }
}
