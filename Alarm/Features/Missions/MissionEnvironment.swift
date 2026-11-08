//
//  MissionEnvironment.swift
//  RiseUp
//
//  LAYER: Logic (a tiny helper, no UI)
//  WHAT:  Answers "are we in the Simulator?" for the sensor and camera missions.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: Shake / Steps / Squat / Photo / Barcode mission ViewModels
//
//  WHY: the Simulator has no motion sensor and no camera. There, sensor missions show a
//  "Simulate" button so we can still test the whole flow. On a REAL iPhone a missing
//  sensor or a denied permission instead swaps the mission for Math (see MissionView),
//  so nobody can get stuck with an alarm they can't turn off, and nobody can skip it either.
//

import Foundation

nonisolated enum MissionEnvironment {
    /// True when running in the iOS Simulator (or an Xcode Preview).
    ///
    /// LEARN: `#if targetEnvironment(simulator)` is decided when the app is BUILT, not while
    /// it runs. The App Store build for iPhones simply doesn't contain the simulator branch.
    static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()
}
