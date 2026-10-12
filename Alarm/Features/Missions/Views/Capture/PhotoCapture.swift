//
//  PhotoCapture.swift
//  RiseUp
//
//  LAYER: View (reusable capture piece: SwiftUI ↔ UIKit bridge)
//  WHAT:  `.photoCapture(isPresented:onImage:)`: opens the camera, hands back a UIImage.
//         In the Simulator (no camera) it opens the photo library instead, so we can test.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← USED BY: MissionPickerView (register the photo spot), PhotoMissionView (the morning photo)
//    → USES:    UIImagePickerController (camera), PhotosPicker (Simulator library)
//
//  LEARN: UIViewControllerRepresentable
//  ────────────────────────────────────
//  SwiftUI has no camera view of its own. UIKit (the older UI framework) does:
//  `UIImagePickerController`. A "representable" wraps a UIKit screen so SwiftUI can show it.
//  The `Coordinator` is a small helper object that receives UIKit's delegate callbacks
//  ("the user took a photo") and passes them back to SwiftUI through a closure.
//

import PhotosUI
import SwiftUI
import UIKit

extension View {
    /// Shows the camera (or, in the Simulator only, the photo library) while `isPresented` is true.
    func photoCapture(isPresented: Binding<Bool>, onImage: @escaping (UIImage) -> Void) -> some View {
        modifier(PhotoCaptureModifier(isPresented: isPresented, onImage: onImage))
    }
}

private struct PhotoCaptureModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void
    @State private var libraryItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        if CameraAccess.usesRealCamera {
            content.fullScreenCover(isPresented: $isPresented) {
                CameraPicker(
                    onImage: { image in
                        isPresented = false
                        onImage(image)
                    },
                    onCancel: { isPresented = false }
                )
                .ignoresSafeArea()
            }
        } else {
            // WHY the library ONLY in the Simulator: in the real app, choosing an old photo
            // from the library would let a sleepy user cheat. On an iPhone this branch never
            // runs (the ViewModels switch to Math if there's no camera at all).
            content
                .photosPicker(isPresented: $isPresented, selection: $libraryItem, matching: .images)
                .onChange(of: libraryItem) {
                    guard let item = libraryItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            onImage(image)
                        }
                        libraryItem = nil
                    }
                }
        }
    }
}

/// The system camera screen, wrapped for SwiftUI.
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        // Keep the coordinator's closures fresh if SwiftUI rebuilt this struct.
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// LEARN: UIKit talks through "delegates": objects with agreed method names. UIKit calls
    /// `imagePickerController(_:didFinishPickingMediaWithInfo:)` when a photo is taken.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
