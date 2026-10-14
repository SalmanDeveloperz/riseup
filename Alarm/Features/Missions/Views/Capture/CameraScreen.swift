//
//  CameraScreen.swift
//  RiseUp
//
//  LAYER: View (reusable capture piece)
//  WHAT:  RiseUp's own full-screen camera: appears instantly, shows "Starting camera…" while the
//         hardware wakes up, then fades the live picture in. Big shutter, torch, cancel.
//  DATA:  none stored; the photo goes back through `onImage`.
//
//  CONNECTIONS:
//    ← SHOWN BY: PhotoCapture (`.photoCapture` modifier) → used by MissionPickerView, PhotoMissionView
//    → USES:     CameraSession (start/stop/capture/torch, all off the main thread)
//
//  WHY not UIImagePickerController any more: see CameraSession's WHY (it froze the app).
//  Bonus: the system camera had a "Use Photo / Retake" step. A half-asleep user doesn't need
//  it: one tap on the shutter and the check starts.
//

import AVFoundation
import SwiftUI

struct CameraScreen: View {
    /// Short hint at the top, e.g. "Photograph your sink".
    let title: String
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    private enum Phase { case starting, ready, capturing, failed }

    @State private var phase: Phase = .starting
    @State private var hasTorch = false
    @State private var isTorchOn = false
    /// Counts shutter presses, to trigger the white flash + haptic.
    @State private var shots = 0
    @State private var isFlashing = false

    private let camera = CameraSession.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .opacity(phase == .starting || phase == .failed ? 0 : 1)
                .animation(.easeOut(duration: 0.35), value: phase)

            if phase == .starting {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView().tint(Theme.Colors.textPrimary)
                    Text("Starting camera…")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .transition(.opacity)
            }

            if phase == .failed {
                failedMessage
            }

            // The white "shutter" flash.
            Color.white.ignoresSafeArea()
                .opacity(isFlashing ? 0.8 : 0)
                .allowsHitTesting(false)

            controls
        }
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .medium), trigger: shots)
        .task {
            // → CameraSession: configure + start on its background queue. The UI is already visible.
            async let torch = camera.hasTorch()
            let started = await camera.start()
            hasTorch = await torch
            withAnimation { phase = started ? .ready : .failed }
        }
        .onDisappear { camera.stop() }          // camera + torch off when the screen closes
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            HStack {
                circleButton("xmark", label: "Cancel", action: onCancel)
                Spacer()
                if hasTorch {
                    circleButton(isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                 label: isTorchOn ? "Turn torch off" : "Turn torch on") {
                        isTorchOn.toggle()
                        camera.setTorch(isTorchOn)
                    }
                }
            }
            Text(title)
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(.ultraThinMaterial, in: .capsule)
                .padding(.top, Theme.Spacing.xs)

            Spacer()

            shutterButton
                .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var shutterButton: some View {
        Button {
            Task { await takePhoto() }
        } label: {
            ZStack {
                Circle().strokeBorder(Theme.Colors.textPrimary, lineWidth: 5)
                    .frame(width: 84, height: 84)
                Circle().fill(Theme.Gradients.brand)
                    .frame(width: 66, height: 66)
                if phase == .capturing {
                    ProgressView().tint(Theme.Colors.textPrimary)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(phase != .ready)                   // no double photos, no shots before the camera is on
        .opacity(phase == .ready || phase == .capturing ? 1 : 0.4)
        .accessibilityLabel("Take photo")
    }

    private func circleButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private var failedMessage: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "camera.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.warning)
            Text("The camera couldn't start. Close this and try again.")
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Taking the photo

    private func takePhoto() async {
        guard phase == .ready else { return }
        phase = .capturing
        shots += 1
        withAnimation(.easeOut(duration: 0.08)) { isFlashing = true }
        withAnimation(.easeIn(duration: 0.25).delay(0.08)) { isFlashing = false }
        if let image = await camera.capturePhoto() {   // → CameraSession (background)
            onImage(image)
        } else {
            phase = .ready                             // rare: just let them press again
        }
    }
}

// MARK: - Live preview

/// Shows what the camera sees.
/// LEARN: a UIView whose `layerClass` is AVCaptureVideoPreviewLayer IS the preview: no copying of
/// frames through our code, iOS draws them straight onto the screen.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }   // safe: see layerClass
    }
}
