//
//  StepsMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15e: Steps)
//  WHAT:  Counts steps from the pedometer until the target is reached. Walking out of the
//         bedroom is one of the best ways to really wake up.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (gets the shared StepCounting from AppDependencies)
//    → USES:       StepCounting.start/stop (CoreMotionStepCounter on device)
//    → onInteraction: each new step count → RingingViewModel.userInteracted()
//    → onComplete:    target reached → RingingViewModel.missionFinished()
//    → onUnavailable: no pedometer / permission denied → MissionView swaps in Math
//

import Foundation
import Observation

@Observable
final class StepsMissionViewModel {
    let target: Int
    private(set) var steps = 0
    /// True in the Simulator: the View shows "Simulate steps".
    private(set) var canSimulate = false

    var remaining: Int { max(0, target - steps) }
    var progress: Double { Double(steps) / Double(max(target, 1)) }

    private let counter: any StepCounting
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private let onUnavailable: () -> Void
    private var isDone = false
    /// True between start() and stop()/done: this ViewModel owns the pedometer right now.
    private var isRunning = false

    init(mission: MissionDraft, counter: any StepCounting,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void,
         onUnavailable: @escaping () -> Void = {}) {
        self.target = mission.repetitions
        self.counter = counter
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.onUnavailable = onUnavailable
    }

    /// ← CALLED BY: StepsMissionView `.onAppear`
    func start() {
        guard counter.isAvailable else {
            // Simulator → offer the button. Real iPhone without step counting → Math instead.
            if MissionEnvironment.isSimulator { canSimulate = true } else { onUnavailable() }
            return
        }
        isRunning = true
        counter.start(
            onSteps: { [weak self] total in self?.update(total) },
            onUnavailable: { [weak self] in
                // e.g. the user tapped "Don't Allow" in the Motion & Fitness popup just now.
                guard let self else { return }
                if MissionEnvironment.isSimulator { self.canSimulate = true } else { self.onUnavailable() }
            }
        )
    }

    /// ← CALLED BY: StepsMissionView `.onDisappear`
    /// WHY the `isRunning` check (found in code review): two Steps missions in a row share ONE
    /// sensor. The first mission's view disappears AFTER the second one started; without this
    /// check its stop() would switch the sensor off under the second mission, and the user
    /// could never finish it.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        counter.stop()            // battery!
    }

    /// ← CALLED BY: the Simulator button (5 steps per tap)
    func simulateSteps() {
        update(steps + 5)
    }

    /// The pedometer reports the TOTAL since start, not "one more step".
    private func update(_ total: Int) {
        guard !isDone, total > steps else { return }
        steps = min(total, target)
        onInteraction()                      // walking counts as "still awake"
        if steps >= target {
            isDone = true
            stop()
            onComplete()                     // → RingingViewModel.missionFinished()
        }
    }
}
