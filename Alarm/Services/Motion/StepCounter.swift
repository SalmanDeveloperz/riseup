//
//  StepCounter.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  Counts the steps taken since the Steps mission started, using the iPhone's pedometer.
//  DATA:  none stored. Needs the "Motion & Fitness" permission (NSMotionUsageDescription).
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → CoreMotionStepCounter, preview → MockStepCounter)
//    ← USED BY:    StepsMissionViewModel (start/stop), AlarmHealthCheckViewModel (permission)
//    → USES:       CoreMotion (CMPedometer)
//
//  LEARN: the pedometer vs. the motion sensor
//  ──────────────────────────────────────────
//  The Shake mission reads raw acceleration (no permission needed). Steps are different:
//  the motion coprocessor already counts them for the Health app, and that IS private data,
//  so iOS asks the user first ("Allow RiseUp to access your Motion & Fitness activity?").
//  Steps also arrive in small batches every few seconds, not instantly.
//

import CoreMotion
import Foundation

protocol StepCounting: AnyObject {
    /// False if this iPhone can't count steps, or the user said "Don't Allow".
    var isAvailable: Bool { get }
    /// Starts counting from zero. `onSteps` gets the TOTAL so far, on the main thread.
    /// `onUnavailable` runs if counting fails (e.g. permission denied in the popup).
    func start(onSteps: @escaping @MainActor (Int) -> Void, onUnavailable: @escaping @MainActor () -> Void)
    func stop()
}

final class CoreMotionStepCounter: StepCounting {
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        let status = CMPedometer.authorizationStatus()
        return CMPedometer.isStepCountingAvailable() && status != .denied && status != .restricted
    }

    func start(onSteps: @escaping @MainActor (Int) -> Void, onUnavailable: @escaping @MainActor () -> Void) {
        guard isAvailable else {
            onUnavailable()
            return
        }
        // WHY `@Sendable` (very important!): CMPedometer calls this closure on a BACKGROUND
        // thread. Without `@Sendable`, Swift 6 would assume the closure belongs to the main
        // actor (it's written inside main-actor code) and the app would CRASH the first time
        // iOS calls it from another thread. `@Sendable` = "may run anywhere"; we then hop
        // back to the main actor ourselves with `Task { @MainActor in … }`.
        pedometer.startUpdates(from: .now) { @Sendable data, error in
            // Copy the number out first: `data` itself isn't safe to pass between threads.
            let steps = data?.numberOfSteps.intValue
            let failed = error != nil
            Task { @MainActor in
                if let steps {
                    onSteps(steps)
                } else if failed {
                    onUnavailable()
                }
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}

/// Fake pedometer for Previews, tests and the Simulator: call `simulateSteps(_:)` yourself.
final class MockStepCounter: StepCounting {
    private var total = 0
    private var onSteps: (@MainActor (Int) -> Void)?
    var isAvailable: Bool { true }

    func start(onSteps: @escaping @MainActor (Int) -> Void, onUnavailable: @escaping @MainActor () -> Void) {
        total = 0
        self.onSteps = onSteps
    }

    func stop() { onSteps = nil }

    func simulateSteps(_ count: Int) {
        total += count
        onSteps?(total)
    }
}
