//
//  PhotoCapture.swift
//  RiseUp
//
//  LAYER: View (reusable capture piece: SwiftUI ↔ UIKit bridge)
//  WHAT:  `.photoCapture(isPresented:title:onImage:)`: opens the camera, hands back a UIImage.
//         In the Simulator (no camera) it opens the photo library instead, so we can test.
//  DATA:  none stored.
//
//  CONNECTIONS:
//    ← USED BY: MissionPickerView (register the photo spot), PhotoMissionView (the morning photo)
//    → USES:    CameraScreen (our fast camera), PhotosPicker (Simulator library)
//
//  WHY our own CameraScreen instead of Apple's UIImagePickerController: the picker started the
//  camera on the main thread and froze the app for seconds on a real iPhone (see CameraSession).
//
//  LEARN: a custom ViewModifier
//  ────────────────────────────
//  `.photoCapture(...)` hides the "camera or library?" decision in one place, so the two
//  screens that need a photo just say "show the camera now" with a Bool.
//

import PhotosUI
import SwiftUI

extension View {
    /// Shows the camera (or, in the Simulator only, the photo library) while `isPresented` is true.
    /// `title` is the hint shown on top of the camera, e.g. "Photograph the same spot".
    func photoCapture(isPresented: Binding<Bool>, title: String, onImage: @escaping (UIImage) -> Void) -> some View {
        modifier(PhotoCaptureModifier(isPresented: isPresented, title: title, onImage: onImage))
    }
}

private struct PhotoCaptureModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let onImage: (UIImage) -> Void
    @State private var libraryItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        if CameraAccess.usesRealCamera {
            content.fullScreenCover(isPresented: $isPresented) {
                CameraScreen(
                    title: title,
                    onImage: { image in
                        isPresented = false
                        onImage(image)
                    },
                    onCancel: { isPresented = false }
                )
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
