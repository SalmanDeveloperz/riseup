//
//  SquatDetector.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock) + pure counting logic
//  WHAT:  Counts squats while the user holds the phone against their chest.
//  DATA:  none. No permission needed (raw motion data, like the Shake mission).
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → CoreMotionSquatDetector, preview → MockSquatDetector)
//    ← USED BY:    SquatMissionViewModel
//    → USES:       CoreMotion (device motion: acceleration + gravity direction),
//                  SquatRepCounter (the counting rule, unit-tested)
//
//  LEARN: How a squat looks to the sensor
//  ──────────────────────────────────────
//  "Vertical acceleration" = how fast your up/down speed changes (in g).
//     going DOWN starts  → negative push   ▁▁╲__
//     bottom, going UP   → positive push       ╱‾‾╲
//  So one squat = a clear dip below −threshold, followed soon by a rise above +threshold.
//  `gravity` tells us which way is "down" however the phone is held, so we measure along it.
//

import CoreMotion
import Foundation

protocol SquatDetecting: AnyObject {
    /// Whether this device has the motion sensor (the Simulator doesn't).
    var isAvailable: Bool { get }
    /// Starts listening; `onSquat` runs on the main thread once per squat.
    func start(onSquat: @escaping @MainActor () -> Void)
    func stop()
}

// MARK: - The counting rule (pure, tested in MissionLogicTests)

/// Turns a stream of vertical-acceleration readings into squat counts.
nonisolated struct SquatRepCounter: Sendable {
    /// Acceleration (in g) a dip/rise must pass. TRY: 0.12 if squats aren't counted on your iPhone.
    let threshold: Double
    /// Fastest possible squat, in seconds. Stops one squat from counting twice.
    let minimumInterval: Double
    /// A rise must follow the dip within this time (otherwise the dip is forgotten).
    var maximumDipToRise: Double = 2.5

    private var dipTime: Double?
    private var lastRepTime = -Double.infinity

    init(threshold: Double, minimumInterval: Double) {
        self.threshold = threshold
        self.minimumInterval = minimumInterval
    }

    /// Feed one reading. Returns `true` when this reading completes a squat.
    /// - Parameters:
    ///   - vertical: upward acceleration in g (negative = accelerating downwards)
    ///   - time: seconds, from any fixed starting point
    mutating func add(vertical: Double, at time: Double) -> Bool {
        if vertical < -threshold {
            dipTime = time                                  // going down…
            return false
        }
        if vertical > threshold, let dip = dipTime, time - dip <= maximumDipToRise,
           time - lastRepTime >= minimumInterval {
            lastRepTime = time                              // …and back up: one squat!
            dipTime = nil
            return true
        }
        return false
    }
}

// MARK: - Real sensor

final class CoreMotionSquatDetector: SquatDetecting {
    private let motion = CMMotionManager()
    private var counter = SquatRepCounter(threshold: 0.18, minimumInterval: 0.9)
    /// Smoothed vertical acceleration (removes tiny hand jitters).
    private var smoothed = 0.0

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start(onSquat: @escaping @MainActor () -> Void) {
        guard motion.isDeviceMotionAvailable else { return }
        counter = SquatRepCounter(threshold: 0.18, minimumInterval: 0.9)
        smoothed = 0
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        // `to: .main` → readings arrive on the main thread (same as ShakeDetector).
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let a = data.userAcceleration, g = data.gravity
                // LEARN: the "dot product" a·g measures how much of `a` points along gravity
                // (= downwards). Minus that = upward acceleration.
                let vertical = -(a.x * g.x + a.y * g.y + a.z * g.z)
                // LEARN: a "low-pass filter": move 25% towards each new reading, so quick
                // jitters are smoothed away but a real squat still comes through.
                self.smoothed += 0.25 * (vertical - self.smoothed)
                if self.counter.add(vertical: self.smoothed, at: data.timestamp) {
                    onSquat()
                }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}

/// Fake sensor for Previews, tests and the Simulator: call `simulateSquat()` yourself.
final class MockSquatDetector: SquatDetecting {
    private var onSquat: (@MainActor () -> Void)?
    var isAvailable: Bool { true }

    func start(onSquat: @escaping @MainActor () -> Void) { self.onSquat = onSquat }
    func stop() { onSquat = nil }
    func simulateSquat() { onSquat?() }
}
