//
//  MemoryPatternGenerator.swift
//  RiseUp
//
//  LAYER: Logic (pure functions, no UI)
//  WHAT:  How big the Memory grid is, how many tiles light up, and which ones, per difficulty.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: MemoryMissionViewModel (a new pattern each round),
//               MissionPickerViewModel (the "example" text), MissionLogicTests
//
//  LEARN: tiles are numbered 0, 1, 2 … row by row. In a 3×3 grid:
//      0 1 2
//      3 4 5
//      6 7 8
//  So a pattern is just a `Set<Int>`, e.g. [0, 4, 8] = the diagonal.
//

import Foundation

nonisolated enum MemoryPatternGenerator {

    /// The settings for one difficulty.
    struct Level: Equatable, Sendable {
        /// Tiles per row (and per column).
        let gridSize: Int
        /// How many tiles light up.
        let litTiles: Int
        /// How long the pattern stays visible.
        let showSeconds: Double
    }

    /// TRY: give "Very hard" 6×6 tiles (`gridSize: 6`) and see if you can still do it.
    static func level(for difficulty: MissionDifficulty) -> Level {
        switch difficulty {
        case .veryEasy: Level(gridSize: 3, litTiles: 3, showSeconds: 2.0)
        case .easy: Level(gridSize: 3, litTiles: 4, showSeconds: 2.0)
        case .normal: Level(gridSize: 4, litTiles: 5, showSeconds: 2.2)
        case .hard: Level(gridSize: 4, litTiles: 7, showSeconds: 2.6)
        case .veryHard: Level(gridSize: 5, litTiles: 9, showSeconds: 3.0)
        }
    }

    /// A random set of tiles to light up.
    ///
    /// LEARN: `(0..<n).shuffled().prefix(k)` = "shuffle all tile numbers, take the first k".
    /// That can never pick the same tile twice.
    static func makePattern(for difficulty: MissionDifficulty) -> Set<Int> {
        let level = level(for: difficulty)
        let tileCount = level.gridSize * level.gridSize
        return Set((0..<tileCount).shuffled().prefix(level.litTiles))
    }
}
