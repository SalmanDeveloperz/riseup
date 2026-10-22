//
//  ShakeDetector.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  Counts phone shakes for the Shake mission, using the motion sensor.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → CoreMotionShakeDetector, preview → MockShakeDetector)
//    ← USED BY:    ShakeMissionViewModel (start/stop; each shake = one step of progress)
//    → USES:       CoreMotion (CMMotionManager device-motion updates)
//
//  LEARN: How "a shake" is detected
//  ────────────────────────────────
//  The sensor reports the phone's acceleration (in g, where 1 g = gravity) 50 times a second.
//  We use `userAcceleration`, which has gravity already removed, so holding the phone
//  still reads ~0. A shake is a sudden peak above a threshold. Harder difficulty =
//  higher threshold = more vigorous shaking. After a shake we ignore the sensor for
//  0.25 s, so one swing back-and-forth isn't counted twice ("debouncing").
//
//  No permission popup is needed: raw motion data isn't private like steps or location.
//

import CoreMotion
import Foundation

protocol ShakeDetecting: AnyObject {
    /// Whether this device has the sensor (the Simulator doesn't).
    var isAvailable: Bool { get }
    /// Starts listening; `onShake` runs on the main thread once per detected shake.
    func start(difficulty: MissionDifficulty, onShake: @escaping @MainActor () -> Void)
    func stop()
}

final class CoreMotionShakeDetector: ShakeDetecting {
    private let motion = CMMotionManager()
    private var lastShake = Date.distantPast

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start(difficulty: MissionDifficulty, onShake: @escaping @MainActor () -> Void) {
        guard motion.isDeviceMotionAvailable else { return }
        let threshold = Self.threshold(for: difficulty)
        motion.deviceMotionUpdateInterval = 1.0 / 50.0

        // LEARN: `to: .main` delivers each reading on the main thread. Swift doesn't know
        // that from the type, so `MainActor.assumeIsolated` tells it "trust me, we're on
        // the main thread here", which lets us touch main-actor state safely.
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let a = data.userAcceleration
                let strength = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                let now = Date.now
                if strength > threshold && now.timeIntervalSince(self.lastShake) > 0.25 {
                    self.lastShake = now
                    onShake()
                }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    /// Peak acceleration (in g) needed to count as one shake.
    /// TRY: lower `.normal` to 1.2 if shaking feels too hard on your iPhone.
    static func threshold(for difficulty: MissionDifficulty) -> Double {
        switch difficulty {
        case .veryEasy: 0.9
        case .easy: 1.2
        case .normal: 1.5
        case .hard: 1.9
        case .veryHard: 2.3
        }
    }
}

/// Fake sensor for Previews, tests and the Simulator: call `simulateShake()` yourself.
final class MockShakeDetector: ShakeDetecting {
    private var onShake: (@MainActor () -> Void)?
    var isAvailable: Bool { false }

    func start(difficulty: MissionDifficulty, onShake: @escaping @MainActor () -> Void) {
        self.onShake = onShake
    }

    func stop() { onShake = nil }

    func simulateShake() { onShake?() }
}
