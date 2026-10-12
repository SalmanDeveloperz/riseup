//
//  CameraAccess.swift
//  RiseUp
//
//  LAYER: Service (small helper around the camera permission + image resizing)
//  WHAT:  • Is the camera allowed? Ask for it (the system popup) when needed.
//         • Is there a camera at all? (The Simulator has none.)
//         • Shrink and straighten a photo before Vision looks at it.
//  DATA:  none. Needs NSCameraUsageDescription (set in the project's build settings).
//
//  CONNECTIONS:
//    ← USED BY: PhotoMissionViewModel, BarcodeMissionViewModel, MissionPickerViewModel,
//               AlarmHealthCheckViewModel, OnboardingViewModel
//    → USES:    AVFoundation (AVCaptureDevice authorization), UIKit (UIImage drawing)
//

import AVFoundation
import UIKit

nonisolated enum CameraPermission: Sendable {
    case notDetermined, allowed, denied
}

enum CameraAccess {
    /// Current answer, no popup.
    static var permission: CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .allowed
        case .notDetermined: .notDetermined
        default: .denied            // denied or restricted (e.g. parental controls)
        }
    }

    /// True if the device has a camera.
    static var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// True when missions should use the REAL camera: a real iPhone with a camera.
    ///
    /// WHY not just `hasCamera`: newer Simulators report a camera, but it's a grey test
    /// picture whose shutter does nothing. In the Simulator we always use the photo library
    /// (photo) or a text field (barcode) instead, so the whole flow can still be tested.
    static var usesRealCamera: Bool {
        hasCamera && !MissionEnvironment.isSimulator
    }

    /// Shows the system popup the first time; returns whether the camera may be used.
    ///
    /// WHY ask BEFORE opening the camera: if the user had said no earlier, the camera screen
    /// would just be black. Asking first lets us show a helpful message instead.
    static func requestIfNeeded() async -> Bool {
        switch permission {
        case .allowed: return true
        case .denied: return false
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    /// A smaller, upright copy of `image` as JPEG data.
    ///
    /// WHY: camera photos are 12+ megapixels and may be stored "sideways" with a rotation
    /// flag. Vision works just as well on ~640 px, much faster, and drawing the image again
    /// bakes the rotation in.
    /// TRY: use 320 for `maxSide` and see if matching still works.
    static func jpegData(from image: UIImage, maxSide: CGFloat = 640, quality: CGFloat = 0.8) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                       // pixels = points, so the size is exact
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
