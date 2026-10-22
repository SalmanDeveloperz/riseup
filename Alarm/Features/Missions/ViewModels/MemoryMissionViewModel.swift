//
//  MemoryMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15d: Memory)
//  WHAT:  Lights up a pattern of tiles for a moment, then the user taps the same tiles.
//         One wrong tap → the answer is shown and a NEW pattern starts. Repeat for N rounds.
//  DATA:  none stored. Uses a MissionDraft (difficulty + how many rounds).
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (Ringing screen, or "Try it" in the Mission Picker)
//    → onInteraction: every tap → RingingViewModel.userInteracted() (keeps the alarm quiet)
//    → onComplete:    after the last round → RingingViewModel.missionFinished()
//    → USES:          MemoryPatternGenerator (pure logic)
//
//  THE ROUND, as a tiny state machine (`phase`):
//     .memorize ──(after showSeconds)──▶ .recall ──(all found)──▶ .roundComplete ──▶ next round / done
//                                           │
//                                           └──(wrong tile)──▶ .mistake ──(1.2 s)──▶ new .memorize
//

import Foundation
import Observation

@Observable
final class MemoryMissionViewModel {

    enum Phase: Equatable {
        case memorize
        case recall
        case mistake
        case roundComplete
    }

    /// What one tile looks like right now. The View only maps these to colours.
    enum TileState {
        case dark       // nothing
        case lit        // part of the pattern, while memorising
        case found      // correctly tapped (green)
        case wrong      // the wrong tap (red)
        case missed     // part of the pattern the user didn't find (shown after a mistake)
    }

    // MARK: - State the View reads

    private(set) var phase: Phase = .memorize
    private(set) var roundsDone = 0
    /// Flips on each mistake (red flash + error haptic in the View).
    private(set) var mistakeCount = 0

    let total: Int
    let level: MemoryPatternGenerator.Level

    var gridSize: Int { level.gridSize }

    /// "Remember the glowing tiles" / "Now tap them" …
    var instruction: String {
        switch phase {
        case .memorize: "Remember the glowing tiles"
        case .recall: "Tap the tiles that glowed (\(found.count)/\(pattern.count))"
        case .mistake: "Oops! Here's the answer. New pattern…"
        case .roundComplete: roundsDone >= total ? "Perfect!" : "Nice! Next round…"
        }
    }

    // MARK: - Private

    private var pattern: Set<Int> = []
    private var found: Set<Int> = []
    private var wrongTile: Int?
    private let difficulty: MissionDifficulty
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    /// The running timer (show pattern → hide it, or wait → next round). Cancelled on stop().
    private var timer: Task<Void, Never>?

    init(mission: MissionDraft, onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.total = mission.repetitions
        self.difficulty = mission.difficulty
        self.level = MemoryPatternGenerator.level(for: mission.difficulty)
        self.onInteraction = onInteraction
        self.onComplete = onComplete
    }

    // MARK: - Lifecycle

    /// ← CALLED BY: MemoryMissionView `.onAppear`
    func start() {
        guard roundsDone < total else { return }
        // Fresh start, OR coming back after stop() cancelled a pending timer (found in code
        // review: the round could stay frozen in "memorize" with every tile disabled).
        if pattern.isEmpty || (timer == nil && phase != .recall) {
            startRound()
        }
    }

    /// ← CALLED BY: MemoryMissionView `.onDisappear`
    /// WHY: a timer left running would change the state of a screen that's gone.
    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Actions

    /// ← CALLED BY: tapping a tile
    func tap(_ index: Int) {
        guard phase == .recall else { return }   // taps while memorising don't count
        onInteraction()                          // → keeps the alarm quiet

        if pattern.contains(index) {
            found.insert(index)
            if found == pattern { finishRound() }
        } else {
            // WHY a fresh pattern after a mistake: otherwise the user would just remember the
            // answer we showed them and tap it again without really thinking.
            wrongTile = index
            mistakeCount += 1
            phase = .mistake
            after(seconds: 1.2) { $0.startRound() }
        }
    }

    func state(of index: Int) -> TileState {
        switch phase {
        case .memorize:
            return pattern.contains(index) ? .lit : .dark
        case .recall:
            return found.contains(index) ? .found : .dark
        case .mistake:
            if index == wrongTile { return .wrong }
            if found.contains(index) { return .found }
            return pattern.contains(index) ? .missed : .dark
        case .roundComplete:
            return pattern.contains(index) ? .found : .dark
        }
    }

    // MARK: - Rounds

    private func startRound() {
        pattern = MemoryPatternGenerator.makePattern(for: difficulty)
        found = []
        wrongTile = nil
        phase = .memorize
        after(seconds: level.showSeconds) { $0.phase = .recall }
    }

    private func finishRound() {
        roundsDone += 1
        phase = .roundComplete
        if roundsDone >= total {
            // A short pause so the user SEES the last tile turn green before the screen changes.
            after(seconds: 0.5) { $0.onComplete() }   // → RingingViewModel.missionFinished()
        } else {
            after(seconds: 0.9) { $0.startRound() }
        }
    }

    /// Runs `action` after a delay, unless stop() was called in the meantime.
    ///
    /// LEARN: `Task.sleep` pauses only this little task, not the app. `[weak self]` means
    /// "don't keep this ViewModel alive just for the timer": if the screen closed, self is
    /// nil and nothing happens.
    private func after(seconds: Double, _ action: @escaping @MainActor (MemoryMissionViewModel) -> Void) {
        timer?.cancel()
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.timer = nil                    // nothing pending any more (see start())
            action(self)
        }
    }
}
