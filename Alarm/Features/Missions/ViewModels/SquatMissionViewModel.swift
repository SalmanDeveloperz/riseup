//
//  SquatMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15f: Squats)
//  WHAT:  Counts squats (phone held against the chest) down to zero.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (gets the shared SquatDetecting from AppDependencies)
//    → USES:       SquatDetecting.start/stop (CoreMotionSquatDetector on device)
//    → onInteraction / onComplete / onUnavailable: same contract as the other sensor missions
//

import Foundation
import Observation

@Observable
final class SquatMissionViewModel {
    let target: Int
    private(set) var count = 0
    /// True in the Simulator: the View shows "Simulate squat".
    private(set) var canSimulate = false

    var remaining: Int { max(0, target - count) }
    var progress: Double { Double(count) / Double(max(target, 1)) }

    private let detector: any SquatDetecting
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private let onUnavailable: () -> Void
    private var isDone = false

    init(mission: MissionDraft, detector: any SquatDetecting,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void,
         onUnavailable: @escaping () -> Void = {}) {
        self.target = mission.repetitions
        self.detector = detector
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.onUnavailable = onUnavailable
    }

    /// ← CALLED BY: SquatMissionView `.onAppear`
    func start() {
        guard detector.isAvailable else {
            if MissionEnvironment.isSimulator { canSimulate = true } else { onUnavailable() }
            return
        }
        detector.start { [weak self] in
            self?.registerSquat()
        }
    }

    /// ← CALLED BY: SquatMissionView `.onDisappear`
    func stop() {
        detector.stop()
    }

    /// One squat (from the sensor, or the Simulator button).
    func registerSquat() {
        guard !isDone else { return }
        onInteraction()
        count += 1
        if count >= target {
            isDone = true
            detector.stop()
            onComplete()                    // → RingingViewModel.missionFinished()
        }
    }
}
