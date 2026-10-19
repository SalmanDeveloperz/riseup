//
//  MissionSafetyTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for mission ViewModels
//  WHAT:  Locks in the fixes from the code review, the bugs that could leave someone stuck
//         with a ringing alarm or skip a mission:
//           • two sensor missions in a row share one sensor: the first must not switch it off
//           • a mission reports "done" exactly once (twice would skip the next mission)
//           • Memory restarts its round if its screen disappears and comes back
//  DATA:  none.
//
//  CONNECTIONS:
//    → TESTS: ShakeMissionViewModel, TypingMissionViewModel, MathMissionViewModel, MemoryMissionViewModel
//

import Foundation
import Testing
@testable import Alarm

/// A fake sensor that says "I'm available" (the app's MockShakeDetector says no, to show
/// the Simulator button). Only one listener at a time, like the real CMMotionManager.
final class AvailableShakeDetector: ShakeDetecting {
    private(set) var listener: (@MainActor () -> Void)?
    var isAvailable: Bool { true }
    func start(difficulty: MissionDifficulty, onShake: @escaping @MainActor () -> Void) { listener = onShake }
    func stop() { listener = nil }
    func shake() { listener?() }
}

@Suite("Mission safety")
struct MissionSafetyTests {

    @Test("A finished Shake mission doesn't switch the sensor off under the next one")
    func backToBackShake() {
        let detector = AvailableShakeDetector()
        let mission = MissionDraft(type: .shake, difficulty: .normal, repetitions: 2)
        var completions = 0
        let first = ShakeMissionViewModel(mission: mission, detector: detector,
                                          onInteraction: {}, onComplete: { completions += 1 })
        let second = ShakeMissionViewModel(mission: mission, detector: detector,
                                           onInteraction: {}, onComplete: { completions += 1 })

        first.start()
        detector.shake(); detector.shake()          // first mission done
        second.start()                              // next mission's screen appears…
        first.stop()                                // …THEN the old one's onDisappear runs
        detector.shake()

        #expect(second.count == 1, "the second mission must still receive shakes")
        #expect(completions == 1)
    }

    @Test("Typing: after a phrase, the box starts EMPTY for the next one, even if the old field writes again")
    func typingNextPhraseStartsEmpty() {
        var completions = 0
        let viewModel = TypingMissionViewModel(
            mission: MissionDraft(type: .typing, difficulty: .veryEasy, repetitions: 2),
            onInteraction: {}, onComplete: { completions += 1 })
        let first = viewModel.phrase

        viewModel.type(first, forPhrase: 0)                  // phrase 1 done
        #expect(viewModel.index == 1 && viewModel.solvedCount == 1)
        #expect(viewModel.typed.isEmpty)

        // What Salman's iPhone 16 did: the old field wrote its text once more on its way out.
        viewModel.type(first, forPhrase: 0)
        viewModel.type(first + "N", forPhrase: 0)
        #expect(viewModel.typed.isEmpty, "a late write from phrase 1's field is ignored")

        // Typing the second phrase in the new field finishes the mission.
        viewModel.type(viewModel.phrase, forPhrase: 1)
        #expect(completions == 1)
    }

    @Test("Typing reports done only once, even if the user keeps typing")
    func typingCompletesOnce() {
        var completions = 0
        let viewModel = TypingMissionViewModel(
            mission: MissionDraft(type: .typing, difficulty: .veryEasy, repetitions: 1),
            onInteraction: {}, onComplete: { completions += 1 })
        let phrase = viewModel.phrase

        viewModel.type(phrase, forPhrase: 0)
        viewModel.type(phrase + "x", forPhrase: 0)
        viewModel.type(phrase, forPhrase: 0)

        #expect(completions == 1)
    }

    @Test("Math reports done only once")
    func mathCompletesOnce() {
        var completions = 0
        let viewModel = MathMissionViewModel(
            mission: MissionDraft(type: .math, difficulty: .veryEasy, repetitions: 1),
            onInteraction: {}, onComplete: { completions += 1 })
        let answer = viewModel.problem.answer

        for digit in String(answer) { viewModel.tapDigit(Int(String(digit))!) }
        viewModel.submit()
        for digit in String(answer) { viewModel.tapDigit(Int(String(digit))!) }
        viewModel.submit()

        #expect(completions == 1)
    }

    @Test("Memory restarts the round when its screen comes back")
    func memoryRestarts() async throws {
        let viewModel = MemoryMissionViewModel(
            mission: MissionDraft(type: .memory, difficulty: .easy, repetitions: 1),
            onInteraction: {}, onComplete: {})
        viewModel.start()
        viewModel.stop()                 // screen disappeared while the pattern was showing
        viewModel.start()                // …and came back

        // Wait for the "memorize" time (2 s on Easy) to pass.
        // WHY a polling loop with a generous limit (found when the test suite grew): other tests
        // running at the same moment can delay this timer a little. We check every 0.1 s and give
        // up only after showSeconds + 4 s, so a busy machine can't make the test fail by accident.
        let deadline = Date.now.addingTimeInterval(viewModel.level.showSeconds + 4)
        while viewModel.phase != .recall && Date.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        // Before the fix, start() did nothing here: no timer, stuck in .memorize, tiles disabled.
        #expect(viewModel.phase == .recall)
    }
}
