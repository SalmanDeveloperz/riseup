//
//  MissionLogicTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing)
//  WHAT:  Checks the pure logic behind missions: maths problems have the right answers,
//         typing is forgiving about case and spaces, every mission's default settings are valid,
//         and the Memory mission's patterns are fair.
//  DATA:  none.
//
//  CONNECTIONS:
//    → TESTS: MathProblemGenerator, TypingPhrases, MissionType rules (MissionDraft.swift),
//             MemoryPatternGenerator
//
//  WHY test random generators many times: a bug that happens 1 time in 50 (e.g. a negative
//  answer) would slip past a single run, and it would happen to a sleepy user at 6 a.m.
//

import Foundation
import Testing
@testable import Alarm

@Suite("Mission logic")
struct MissionLogicTests {

    // MARK: - Math

    /// Re-calculates a problem from its text ("12 × 7 − 30") so we know the stored answer is right.
    func evaluate(_ text: String) -> Int {
        let parts = text.split(separator: " ").map(String.init)
        var numbers = parts.enumerated().filter { $0.offset % 2 == 0 }.map { Int($0.element)! }
        var operators = parts.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        // × first (only one level of precedence is used by the generator)
        while let index = operators.firstIndex(of: "×") {
            numbers[index] = numbers[index] * numbers[index + 1]
            numbers.remove(at: index + 1)
            operators.remove(at: index)
        }
        var result = numbers[0]
        for (i, op) in operators.enumerated() {
            result = op == "+" ? result + numbers[i + 1] : result - numbers[i + 1]
        }
        return result
    }

    @Test("Every math problem's answer matches its text and is positive", arguments: MissionDifficulty.allCases)
    func mathAnswers(difficulty: MissionDifficulty) {
        for _ in 0..<300 {
            let problem = MathProblemGenerator.make(difficulty)
            #expect(evaluate(problem.text) == problem.answer, "\(problem.text) should be \(problem.answer)")
            #expect(problem.answer > 0)
        }
    }

    // MARK: - Typing

    @Test("Typing ignores case, extra spaces and a missing full stop")
    func typingIsForgiving() {
        #expect(TypingPhrases.matches("i am  wide awake", phrase: "I am wide awake."))
        #expect(!TypingPhrases.matches("I am wide awak", phrase: "I am wide awake."))
    }

    @Test("Typing picks the number of phrases asked for", arguments: MissionDifficulty.allCases)
    func typingPick(difficulty: MissionDifficulty) {
        #expect(TypingPhrases.pick(3, difficulty: difficulty).count == 3)
    }

    @Test("Correct prefix length counts matching letters from the start")
    func typingPrefix() {
        #expect(TypingPhrases.correctPrefixLength("Good mx", phrase: "Good morning") == 6)
    }

    // MARK: - Mission rules

    @Test("Each mission's default count is inside its allowed range", arguments: MissionType.allCases)
    func defaultsAreValid(type: MissionType) {
        #expect(type.repetitionRange.contains(type.defaultRepetitions))
        #expect(type.repetitionStep > 0)
    }

    @Test("Every mission type is available now (Phase 3 finished the list)")
    func allMissionsAvailable() {
        #expect(MissionType.allCases.filter { !$0.isAvailable }.isEmpty)
    }

    @Test("Photo and barcode missions need a registration before they can be saved")
    func registrationRules() {
        var photo = MissionDraft.defaults(for: .photo)
        #expect(photo.needsRegistration)
        #expect(!photo.isReadyToSave)
        photo.dataPayload = Data([1, 2, 3])
        #expect(photo.isReadyToSave)

        var barcode = MissionDraft.defaults(for: .barcode)
        #expect(!barcode.isReadyToSave)
        barcode.textPayload = "RISEUP-123"
        #expect(barcode.isReadyToSave)

        #expect(MissionDraft.defaults(for: .math).isReadyToSave)
    }

    // MARK: - Memory

    @Test("Memory patterns have the right number of distinct tiles inside the grid", arguments: MissionDifficulty.allCases)
    func memoryPatterns(difficulty: MissionDifficulty) {
        let level = MemoryPatternGenerator.level(for: difficulty)
        for _ in 0..<200 {
            let pattern = MemoryPatternGenerator.makePattern(for: difficulty)
            #expect(pattern.count == level.litTiles)
            let tiles = 0..<(level.gridSize * level.gridSize)
            #expect(pattern.filter { !tiles.contains($0) }.isEmpty)
        }
        #expect(level.litTiles < level.gridSize * level.gridSize, "some tiles must stay dark")
    }

    @Test("Harder memory levels are never easier than the level below")
    func memoryLevelsGrow() {
        let levels = MissionDifficulty.allCases.map(MemoryPatternGenerator.level(for:))
        for (easier, harder) in zip(levels, levels.dropFirst()) {
            #expect(harder.litTiles >= easier.litTiles)
            #expect(harder.gridSize >= easier.gridSize)
        }
    }

    // MARK: - Squat counting

    @Test("A down-then-up movement counts as one squat; small wobbles don't")
    func squatCounting() {
        var counter = SquatRepCounter(threshold: 0.2, minimumInterval: 0.8)
        var reps = 0
        // Standing still with small noise: nothing.
        for i in 0..<50 { if counter.add(vertical: 0.05 * (i.isMultiple(of: 2) ? 1 : -1), at: Double(i) * 0.02) { reps += 1 } }
        #expect(reps == 0)
        // One squat: going down (negative), then pushing up (positive).
        let squat: [Double] = [-0.1, -0.25, -0.3, -0.1, 0.1, 0.3, 0.35, 0.1, 0.0]
        for (i, v) in squat.enumerated() { if counter.add(vertical: v, at: 2.0 + Double(i) * 0.1) { reps += 1 } }
        #expect(reps == 1)
        // A second squat right after (too soon) still counts once it's 0.8 s later.
        for (i, v) in squat.enumerated() { if counter.add(vertical: v, at: 3.5 + Double(i) * 0.1) { reps += 1 } }
        #expect(reps == 2)
    }
}
