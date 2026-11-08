//
//  MathProblemGenerator.swift
//  RiseUp
//
//  LAYER: Pure logic (no UI, no database, no system APIs)
//  WHAT:  Creates math problems that match a difficulty level.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: MathMissionViewModel (one problem at a time), MissionPickerView (sample problem)
//
//  LEARN: The random number generator is a PARAMETER (`using generator:`). The app passes
//  the system's real randomness; a unit test can pass a fixed "seeded" generator and get
//  the same problems every run. That makes random code testable.
//

import Foundation

/// One problem: the text to show and the correct answer.
nonisolated struct MathProblem: Equatable, Sendable {
    let text: String
    let answer: Int
}

nonisolated enum MathProblemGenerator {

    /// A new problem for `difficulty`.
    ///
    /// The levels, easiest to hardest:
    ///   • Very easy: 7 + 5
    ///   • Easy:      34 + 27
    ///   • Normal:    7 × 8 + 23
    ///   • Hard:      14 × 6 + 57
    ///   • Very hard: 23 × 17 − 148
    /// TRY: make "Very easy" use only numbers 1…5.
    static func make(_ difficulty: MissionDifficulty, using generator: inout some RandomNumberGenerator) -> MathProblem {
        func r(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &generator) }

        switch difficulty {
        case .veryEasy:
            let a = r(1...9), b = r(1...9)
            return MathProblem(text: "\(a) + \(b)", answer: a + b)
        case .easy:
            let a = r(10...49), b = r(10...49)
            return MathProblem(text: "\(a) + \(b)", answer: a + b)
        case .normal:
            let a = r(2...9), b = r(2...9), c = r(10...49)
            return MathProblem(text: "\(a) × \(b) + \(c)", answer: a * b + c)
        case .hard:
            let a = r(11...19), b = r(3...9), c = r(10...99)
            return MathProblem(text: "\(a) × \(b) + \(c)", answer: a * b + c)
        case .veryHard:
            let a = r(12...29), b = r(11...19)
            // Keep the answer positive: subtract less than the product.
            let c = r(100...min(299, a * b - 1))
            return MathProblem(text: "\(a) × \(b) − \(c)", answer: a * b - c)
        }
    }

    /// Convenience for app code: uses the system's random generator.
    static func make(_ difficulty: MissionDifficulty) -> MathProblem {
        var generator = SystemRandomNumberGenerator()
        return make(difficulty, using: &generator)
    }
}
