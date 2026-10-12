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

    @Test("Typing reports done only once, even if the user keeps typing")
    func typingCompletesOnce() {
        var completions = 0
        let viewModel = TypingMissionViewModel(
            mission: MissionDraft(type: .typing, difficulty: .veryEasy, repetitions: 1),
            onInteraction: {}, onComplete: { completions += 1 })
        let phrase = viewModel.phrase

        viewModel.typed = phrase
        viewModel.typed = phrase + "x"
        viewModel.typed = phrase

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

        // Wait a little longer than the "memorize" time (2 s on Easy).
        try await Task.sleep(for: .seconds(viewModel.level.showSeconds + 0.5))
        // Before the fix, start() did nothing here: no timer, stuck in .memorize, tiles disabled.
        #expect(viewModel.phase == .recall)
    }
}
