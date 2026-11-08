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
//    → USES:       ShakeDetecting.start/stop (CoreMotionShakeDetector on device, Mock in previews)
//    → onInteraction / onComplete: same contract as every mission
//    → onUnavailable: no sensor on a real iPhone → MissionView swaps in Math (see MissionEnvironment)
//

import Foundation
import Observation

@Observable
final class ShakeMissionViewModel {
    let target: Int
    private(set) var count = 0

    var remaining: Int { max(0, target - count) }
    var progress: Double { Double(count) / Double(max(target, 1)) }

    /// True in the Simulator (no motion sensor): the View shows a "Simulate shake" button.
    private(set) var canSimulate = false

    private let difficulty: MissionDifficulty
    private let detector: any ShakeDetecting
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private let onUnavailable: () -> Void
    private var isDone = false
    /// True between start() and stop()/done: this ViewModel owns the sensor right now.
    private var isRunning = false

    init(mission: MissionDraft, detector: any ShakeDetecting,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void,
         onUnavailable: @escaping () -> Void = {}) {
        self.target = mission.repetitions
        self.difficulty = mission.difficulty
        self.detector = detector
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.onUnavailable = onUnavailable
    }

    /// ← CALLED BY: ShakeMissionView `.onAppear`
    func start() {
        guard detector.isAvailable else {
            // Simulator → offer the button. Real iPhone without a sensor → Math instead.
            if MissionEnvironment.isSimulator { canSimulate = true } else { onUnavailable() }
            return
        }
        isRunning = true
        detector.start(difficulty: difficulty) { [weak self] in
            self?.registerShake()                       // ← one call per detected shake
        }
    }

    /// ← CALLED BY: ShakeMissionView `.onDisappear`
    /// WHY the `isRunning` check (found in code review): two Shake missions in a row share ONE
    /// sensor. The first mission's view disappears AFTER the second one started; without this
    /// check its stop() would switch the sensor off under the second mission, and the user
    /// could never finish it.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        detector.stop()           // battery: never leave the sensor running
    }

    /// One shake detected (from the sensor, or the Simulator button).
    func registerShake() {
        guard !isDone else { return }
        onInteraction()
        count += 1
        if count >= target {
            isDone = true
            stop()
            onComplete()                                // → RingingViewModel.missionFinished()
        }
    }
}
