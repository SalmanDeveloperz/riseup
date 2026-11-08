//
//  MissionServices.swift
//  RiseUp
//
//  LAYER: Service (a small bundle of services)
//  WHAT:  Every sensor/tool a mission might need, packed into ONE value.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live: real sensors · preview: fakes)
//    ← PASSED TO:  RingingViewModel and MissionPickerViewModel → MissionView
//    → CONTAINS:   ShakeDetecting, StepCounting, SquatDetecting, PhotoMatching
//
//  WHY a bundle: MissionView builds whichever mission is next, so it needs ALL of them.
//  Passing four separate parameters through three layers is noisy; one struct keeps every
//  `init` short, and adding a fifth sensor later changes only this file + AppDependencies.
//

import Foundation

struct MissionServices {
    let shake: any ShakeDetecting
    let steps: any StepCounting
    let squat: any SquatDetecting
    let photoMatcher: any PhotoMatching

    /// Fakes for Xcode Previews.
    static func preview() -> MissionServices {
        MissionServices(
            shake: MockShakeDetector(),
            steps: MockStepCounter(),
            squat: MockSquatDetector(),
            photoMatcher: MockPhotoMatcher()
        )
    }
}
