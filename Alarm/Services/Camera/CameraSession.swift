//
//  CameraSession.swift
//  RiseUp
//
//  LAYER: Service (the camera hardware: start, stop, take a photo, torch)
//  WHAT:  One AVCaptureSession for the whole app, driven from its OWN background queue, so
//         opening the camera never freezes the screen. Can be "pre-warmed" (set up early).
//  DATA:  none stored. Photos are handed back as a small UIImage and never saved here.
//
//  CONNECTIONS:
//    ← USED BY: CameraScreen (live preview, shutter, torch)
//               CameraAccess.prepareCamera() ← PhotoMissionViewModel, MissionPickerViewModel
//    → USES:    AVFoundation (AVCaptureSession, AVCapturePhotoOutput), ImageIO (fast resizing)
//
//  WHY this file exists (Salman's iPhone test): the old camera was Apple's UIImagePickerController.
//  It starts the camera hardware ON THE MAIN THREAD, and the first time that can take 1–3 seconds.
//  The app looked frozen ("did it crash?"). Here, all slow camera work happens on `queue`, a
//  background line of work, while the screen stays responsive and shows "Starting camera…".
//
//  WHY a single shared object (`shared`): an iPhone has one back camera. One session that stays
//  configured makes the 2nd, 3rd… opening almost instant.
//
//  LEARN: why `nonisolated` and `@unchecked Sendable`
//  ──────────────────────────────────────────────────
//  In this project, classes run on the main actor by default. This one must NOT: its whole job
//  is to work off the main thread. `nonisolated` opts out. `@unchecked Sendable` is our promise
//  to Swift: "every mutable property is only touched on `queue`", which makes it safe to share.
//

import AVFoundation
import ImageIO
import UIKit

nonisolated final class CameraSession: NSObject, @unchecked Sendable {
    static let shared = CameraSession()

    /// The live session. The preview layer (CameraScreen) shows what it sees.
    let session = AVCaptureSession()

    /// Every property below is only read/written on this queue (see the LEARN above).
    private let queue = DispatchQueue(label: "riseup.camera", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    /// Photos being taken right now. AVFoundation keeps its delegate WEAKLY, so we must hold it.
    private var inFlight: [Int64: PhotoProcessor] = [:]

    /// Longest side of the photo we hand back. Matching uses 640 px, the thumbnail 320 px.
    /// TRY: 1024 makes taking a photo even faster; 2400 keeps more detail.
    static let maxPhotoSide = 1600

    // MARK: - Starting and stopping

    /// Sets the camera up in the background WITHOUT turning it on (no green dot yet), so a later
    /// `start()` is fast. Safe to call many times.
    func prepare() {
        queue.async { _ = self.configureIfNeeded() }
    }

    /// Turns the camera on. Returns false if this device has no usable back camera.
    /// LEARN: `withCheckedContinuation` turns "call me back later" code into `await`.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.configureIfNeeded() else {
                    continuation.resume(returning: false)
                    return
                }
                if !self.session.isRunning { self.session.startRunning() }   // the slow call, safely off-main
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    /// Turns the camera (and torch) off. Called when the camera screen closes.
    func stop() {
        queue.async {
            self.applyTorch(false)
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    // MARK: - Taking a photo

    /// Takes a photo and returns it upright and resized (≤ `maxPhotoSide`), or nil on failure.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                // WHY .speed: we compare scenes, we don't print posters. Speed = no long "processing" wait.
                settings.photoQualityPrioritization = .speed
                let id = settings.uniqueID
                let processor = PhotoProcessor { image in
                    continuation.resume(returning: image)
                    self.queue.async { self.inFlight[id] = nil }       // let it go
                }
                self.inFlight[id] = processor
                self.photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    // MARK: - Torch

    /// The flashlight, for a dark bedroom at 6 a.m.
    func setTorch(_ isOn: Bool) {
        queue.async { self.applyTorch(isOn) }
    }

    /// True if the back camera has a torch (checked off-main, answered later).
    func hasTorch() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                _ = self.configureIfNeeded()
                continuation.resume(returning: self.device?.hasTorch ?? false)
            }
        }
    }

    // MARK: - Private (always on `queue`)

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // WHY `.high` and not `.photo`: `.photo` means 12+ megapixels, slow to take and to shrink.
        // Full-HD is plenty to recognise a spot.
        session.sessionPreset = .high
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed
        device = camera
        isConfigured = true
        return true
    }

    private func applyTorch(_ isOn: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = isOn ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - One photo being taken

/// Receives the finished photo from AVFoundation (on a background thread) and shrinks it.
nonisolated private final class PhotoProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (UIImage?) -> Void

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            completion(nil)
            return
        }
        completion(Self.uprightImage(from: data, maxSide: CameraSession.maxPhotoSide))
    }

    /// Decodes AND shrinks in one go, already rotated upright.
    /// LEARN: ImageIO's "thumbnail" call never decodes the full 12 MP picture, which makes it
    /// much faster and lighter on memory than drawing a big UIImage smaller.
    static func uprightImage(from data: Data, maxSide: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,      // apply the "sideways" flag
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
