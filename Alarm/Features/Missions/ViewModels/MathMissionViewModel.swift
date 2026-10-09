//
//  MathMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15a: Math)
//  WHAT:  Shows one problem at a time, checks the typed answer, counts solved problems,
//         and reports "done" when enough are solved.
//  DATA:  none stored. Uses a MissionDraft (difficulty + how many problems).
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (inside the Ringing screen, or "Try it" in the Mission Picker)
//    → onInteraction: every key press → RingingViewModel.userInteracted() (keeps the alarm quiet)
//    → onComplete:    after the last problem → RingingViewModel.missionFinished()
//    → USES:          MathProblemGenerator (pure logic)
//

import Foundation
import Observation

@Observable
final class MathMissionViewModel {
    private(set) var problem: MathProblem
    /// What the user has typed so far, e.g. "7" then "79".
    private(set) var input = ""
    private(set) var solved = 0
    /// Flips every time an answer is wrong, so the View can play a "shake" animation.
    private(set) var wrongAnswerCount = 0
    /// Flips every time an answer is right (for a success haptic).
    private(set) var rightAnswerCount = 0

    let total: Int
    private let difficulty: MissionDifficulty
    private let onInteraction: () -> Void
    private let onComplete: () -> Void

    init(mission: MissionDraft, onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.total = mission.repetitions
        self.difficulty = mission.difficulty
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.problem = MathProblemGenerator.make(mission.difficulty)
    }

    /// ← CALLED BY: digit keys
    func tapDigit(_ digit: Int) {
        onInteraction()
        guard input.count < 6 else { return }   // no answer here needs more than 6 digits
        input.append(String(digit))
    }

    /// ← CALLED BY: the ⌫ key
    func deleteDigit() {
        onInteraction()
        if !input.isEmpty { input.removeLast() }
    }

    /// ← CALLED BY: the ✓ key
    func submit() {
        onInteraction()
        guard let value = Int(input) else { return }
        if value == problem.answer {
            solved += 1
            rightAnswerCount += 1
            input = ""
            if solved >= total {
                onComplete()                       // → RingingViewModel.missionFinished()
            } else {
                problem = MathProblemGenerator.make(difficulty)
            }
        } else {
            // WHY keep the same problem after a mistake: a new one would let a sleepy
            // user "skip" hard problems by typing nonsense.
            wrongAnswerCount += 1
            input = ""
        }
    }
}
