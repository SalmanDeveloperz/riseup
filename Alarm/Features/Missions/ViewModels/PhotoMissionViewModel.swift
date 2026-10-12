//
//  PhotoMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15g: Photo)
//  WHAT:  "Go to the spot you registered and take a photo of it." The new photo is compared
//         with the registered one (Vision feature prints). Same place → mission done.
//  DATA:  reads the MissionDraft's dataPayload (PhotoMissionPayload). Stores nothing.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (for missions of type .photo)
//    → USES:       PhotoMatching (VisionPhotoMatcher), CameraAccess (permission, resizing)
//    → onInteraction / onComplete: same contract as every mission
//    → onUnavailable: no camera / camera not allowed / registration damaged → Math instead
//    → onGiveUp:      "Can't match?" after a few failed photos → harder Math instead
//
//  WHY a give-up path: lighting at 6 a.m. can differ a lot from when you registered the
//  photo. Without it, a user could be stuck with a ringing alarm forever. With it, they can
//  still turn the alarm off, but only by doing something harder (5 hard maths problems).
//

import Foundation
import Observation
import UIKit

@Observable
final class PhotoMissionViewModel {

    enum Status: Equatable {
        case ready          // waiting for the user to take a photo
        case checking       // comparing (≈ half a second)
        case noMatch        // last photo didn't match
        case matched        // done!
    }

    // MARK: - State the View reads

    private(set) var status: Status = .ready
    /// Bound to the camera's full-screen cover.
    var isShowingCamera = false
    /// The registered spot, so the user knows what to photograph.
    let referenceImage: UIImage?
    private(set) var failedAttempts = 0
    /// The last measured distance (shown in Debug builds to tune the threshold).
    private(set) var lastDistance: Double?

    /// After this many failed photos, "Can't match? Do maths instead" appears.
    static let attemptsBeforeGiveUp = 3
    var canGiveUp: Bool { failedAttempts >= Self.attemptsBeforeGiveUp }

    var threshold: Double { matcher.matchThreshold }

    // MARK: - Private

    private let payload: PhotoMissionPayload?
    private let matcher: any PhotoMatching
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private let onUnavailable: () -> Void
    private let onGiveUp: () -> Void

    init(mission: MissionDraft, matcher: any PhotoMatching,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void,
         onUnavailable: @escaping () -> Void = {}, onGiveUp: @escaping () -> Void = {}) {
        self.payload = PhotoMissionPayload.decode(mission.dataPayload)
        self.referenceImage = payload.flatMap { UIImage(data: $0.thumbnail) }
        self.matcher = matcher
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.onUnavailable = onUnavailable
        self.onGiveUp = onGiveUp
    }

    // MARK: - Actions

    /// ← CALLED BY: PhotoMissionView `.onAppear`
    func start() {
        // No registered photo (damaged data), or a real device without a camera → Math.
        if payload == nil || (!CameraAccess.usesRealCamera && !MissionEnvironment.isSimulator) {
            onUnavailable()
        }
    }

    /// ← CALLED BY: "Take photo"
    func openCamera() async {
        onInteraction()
        // Simulator: PhotoCapture shows the photo library instead (no permission needed).
        if CameraAccess.usesRealCamera {
            guard await CameraAccess.requestIfNeeded() else {
                onUnavailable()                      // camera not allowed → Math instead
                return
            }
        }
        isShowingCamera = true
    }

    /// ← CALLED BY: PhotoCapture's onImage (a photo was taken)
    func check(_ image: UIImage) async {
        guard let payload, status != .checking, status != .matched else { return }
        onInteraction()
        status = .checking
        do {
            guard let jpeg = CameraAccess.jpegData(from: image) else { throw CocoaError(.fileReadCorruptFile) }
            let fingerprint = try await matcher.fingerprint(of: jpeg)       // → Vision, off the main thread
            let distance = try matcher.distance(between: payload.fingerprint, and: fingerprint)
            lastDistance = distance
            if matcher.isMatch(distance: distance) {
                status = .matched
                try? await Task.sleep(for: .seconds(0.6))                   // let the ✓ show
                onComplete()                                                // → RingingViewModel.missionFinished()
            } else {
                failedAttempts += 1
                status = .noMatch
            }
        } catch {
            failedAttempts += 1
            status = .noMatch
        }
    }

    /// ← CALLED BY: "Can't match? Do maths instead"
    func giveUp() {
        onGiveUp()                                   // → MissionView swaps in harder Math
    }
}
