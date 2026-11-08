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

    /// The text field's content. Changed only through `type(_:forPhrase:)`.
    private(set) var typed = ""

    var total: Int { phrases.count }
    var phrase: String { phrases[min(index, phrases.count - 1)] }

    /// How many characters at the start of the phrase are already typed correctly.
    var correctCount: Int { TypingPhrases.correctPrefixLength(typed, phrase: phrase) }

    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    /// WHY: after the last phrase, typing a letter and deleting it would "match" again and report
    /// done a SECOND time, which would skip the NEXT mission. Report done exactly once.
    private var isDone = false

    init(mission: MissionDraft, onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.phrases = TypingPhrases.pick(mission.repetitions, difficulty: mission.difficulty)
        self.onInteraction = onInteraction
        self.onComplete = onComplete
    }

    /// The text field changed. `phraseIndex` = the phrase that field was showing.
    /// ← CALLED BY: TypingMissionView's text field binding (and tests)
    ///
    /// WHY the phrase number (bug found on Salman's iPhone 16): when a phrase matched, we emptied
    /// `typed` for the next one, but the OLD text field wrote its text back one more time on its way
    /// out ("Today is my day" again), so the next phrase started with the old text in the box. A write
    /// that belongs to an earlier phrase is now simply ignored.
    func type(_ text: String, forPhrase phraseIndex: Int) {
        guard phraseIndex == index else { return }       // a late write from the previous phrase's field
        typed = text
        onInteraction()
        checkMatch()
    }

    private func checkMatch() {
        guard !isDone, TypingPhrases.matches(typed, phrase: phrase) else { return }
        solvedCount += 1
        if solvedCount >= phrases.count {
            isDone = true
            onComplete()                                 // → RingingViewModel.missionFinished()
        } else {
            index += 1
            typed = ""                                   // the next phrase starts empty (see `type`)
        }
    }
}
