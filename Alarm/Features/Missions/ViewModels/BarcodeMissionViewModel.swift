//
//  BarcodeMissionViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Mission 15h: QR / Barcode)
//  WHAT:  "Scan the code you registered." Put the code (a toothpaste box, a QR sticker)
//         in another room, and you have to walk there to switch the alarm off.
//  DATA:  reads the MissionDraft's textPayload (the registered code). Stores nothing.
//
//  CONNECTIONS:
//    ← CREATED BY: MissionView (for missions of type .barcode)
//    → USES:       CameraAccess (permission), BarcodeScanScreen (via the View)
//    → onInteraction / onComplete / onUnavailable / onGiveUp: like the Photo mission
//

import Foundation
import Observation

@Observable
final class BarcodeMissionViewModel {

    enum Status: Equatable {
        case ready
        case wrongCode
        case matched
    }

    private(set) var status: Status = .ready
    /// Bound to the scanner's full-screen cover.
    var isShowingScanner = false
    private(set) var wrongScans = 0

    /// After this many wrong codes, "Can't find it? Do maths instead" appears.
    static let attemptsBeforeGiveUp = 3
    var canGiveUp: Bool { wrongScans >= Self.attemptsBeforeGiveUp }

    private let expectedCode: String?
    private let onInteraction: () -> Void
    private let onComplete: () -> Void
    private let onUnavailable: () -> Void
    private let onGiveUp: () -> Void

    init(mission: MissionDraft,
         onInteraction: @escaping () -> Void, onComplete: @escaping () -> Void,
         onUnavailable: @escaping () -> Void = {}, onGiveUp: @escaping () -> Void = {}) {
        self.expectedCode = mission.textPayload
        self.onInteraction = onInteraction
        self.onComplete = onComplete
        self.onUnavailable = onUnavailable
        self.onGiveUp = onGiveUp
    }

    /// ← CALLED BY: BarcodeMissionView `.onAppear`
    func start() {
        let canScanHere = BarcodeScanScreen.canScan || MissionEnvironment.isSimulator
        if (expectedCode ?? "").isEmpty || (!canScanHere && CameraAccess.permission == .denied) {
            onUnavailable()                     // nothing registered, or camera blocked → Math
        }
    }

    /// ← CALLED BY: "Scan code"
    func openScanner() async {
        onInteraction()
        if CameraAccess.usesRealCamera {
            guard await CameraAccess.requestIfNeeded() else {
                onUnavailable()
                return
            }
            // WHY check again AFTER asking: `isAvailable` only becomes true once access is
            // granted. If it's still false (very old iPhone), this mission can't run here.
            guard BarcodeScanScreen.canScan else {
                onUnavailable()
                return
            }
        }
        isShowingScanner = true
    }

    /// ← CALLED BY: BarcodeScanScreen's onCode
    func scanned(_ code: String) {
        guard status != .matched else { return }
        isShowingScanner = false
        onInteraction()
        if code == expectedCode {
            status = .matched
            Task {
                try? await Task.sleep(for: .seconds(0.6))   // let the ✓ show
                onComplete()                                 // → RingingViewModel.missionFinished()
            }
        } else {
            wrongScans += 1
            status = .wrongCode
        }
    }

    func giveUp() {
        onGiveUp()
    }
}
