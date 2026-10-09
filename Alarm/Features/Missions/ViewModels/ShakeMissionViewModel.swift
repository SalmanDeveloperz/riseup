//
//  ShakeMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15c: Shake)
//  WHAT:  Counts shakes from the motion sensor down to zero.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (gets the shared ShakeDetecting from AppDependencies)
//    → USES:       ShakeDetecting.start/stop (CoreMotionShakeDetector on device, Mock in Simulator)
//    → onInteraction / onComplete: same contract as every mission
//

import Foundation
import Observation

@Observable
final class ShakeMissionViewModel {
    let target: Int
    private(set) var count = 0

    var remaining: Int { max(0, target - count) }
    var progress: Double { Double(count) / Double(max(target, 1)) }

    /// False in the Simulator (no motion sensor). The View then shows a "Simulate shake" button.
    var isSensorAvailable: Bool { detector.isAvailable }

    private let difficulty: MissionDifficulty
    private let detector: any ShakeDetecting
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private var isDone = false

    init(mission: MissionDraft, detector: any ShakeDetecting,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.target = mission.repetitions
        self.difficulty = mission.difficulty
        self.detector = detector
        self.onInteraction = onInteraction
        self.onComplete = onComplete
    }

    /// ← CALLED BY: ShakeMissionView `.onAppear`
    func start() {
        detector.start(difficulty: difficulty) { [weak self] in
            self?.registerShake()                       // ← one call per detected shake
        }
    }

    /// ← CALLED BY: ShakeMissionView `.onDisappear`
    /// WHY always stop: a running motion sensor drains the battery.
    func stop() {
        detector.stop()
    }

    /// One shake detected (from the sensor, or the Simulator button).
    func registerShake() {
        guard !isDone else { return }
        onInteraction()
        count += 1
        if count >= target {
            isDone = true
            detector.stop()
            onComplete()                                // → RingingViewModel.missionFinished()
        }
    }
}
