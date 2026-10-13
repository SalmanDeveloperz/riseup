//
//  PhotoMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15g: Photo)
//  WHAT:  Shows the registered spot, a big "Take photo" button, and the result
//         (checking… / doesn't match / ✓).
//  VIEWMODEL: PhotoMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .photo)
//    → USES:     .photoCapture (camera; photo library in the Simulator)
//

import SwiftUI

struct PhotoMissionView: View {
    @State private var viewModel: PhotoMissionViewModel

    init(viewModel: PhotoMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            MissionProgressHeader(type: .photo, done: viewModel.status == .matched ? 1 : 0, total: 1)

            Text("Go to this spot and take a photo of it")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            reference

            statusLine

            Spacer(minLength: 0)

            Button {
                Task { await viewModel.openCamera() }      // → permission → camera
            } label: {
                Label(viewModel.status == .noMatch ? "Try again" : "Take photo", systemImage: "camera.fill")
            }
            .buttonStyle(.neon)
            .disabled(viewModel.status == .checking || viewModel.status == .matched)

            if viewModel.canGiveUp {
                Button("Can't match? Do 5 hard maths problems instead") { viewModel.giveUp() }
                    .buttonStyle(.ghost)
                    .transition(.opacity)
            }
        }
        .onAppear { viewModel.start() }
        .photoCapture(isPresented: $viewModel.isShowingCamera, title: "Photograph the same spot") { image in
            Task { await viewModel.check(image) }          // → Vision compares the two photos
        }
        .animation(.spring(duration: 0.3), value: viewModel.status)
        .animation(.easeInOut, value: viewModel.canGiveUp)
        .sensoryFeedback(.success, trigger: viewModel.status == .matched)
        .sensoryFeedback(.error, trigger: viewModel.failedAttempts)
    }

    @ViewBuilder
    private var reference: some View {
        if let image = viewModel.referenceImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(.rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(viewModel.status == .matched ? AnyShapeStyle(Theme.Gradients.success) : AnyShapeStyle(Theme.Gradients.sunrise), lineWidth: 3)
                }
                .overlay {
                    if viewModel.status == .matched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(Theme.Gradients.success)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .accessibilityLabel("The registered photo spot")
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch viewModel.status {
        case .ready:
            Text("Similar angle and light work best.")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textSecondary)
        case .checking:
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView().tint(Theme.Colors.neonPink)
                Text("Checking…").foregroundStyle(Theme.Colors.textSecondary)
            }
            .font(.riseBody)
        case .noMatch:
            Label("That doesn't look like the same spot. Get closer and try again.", systemImage: "xmark.circle.fill")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.danger)
                .multilineTextAlignment(.center)
        case .matched:
            Label("Same spot. Well done!", systemImage: "checkmark.seal.fill")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.success)
        }

        #if DEBUG
        // Debug builds only: helps tune VisionPhotoMatcher.matchThreshold on your iPhone.
        if let distance = viewModel.lastDistance {
            Text("Debug · distance \(distance, format: .number.precision(.fractionLength(2))) (match ≤ \(viewModel.threshold, format: .number.precision(.fractionLength(2))))")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        #endif
    }
}

#Preview {
    PhotoMissionView(viewModel: PhotoMissionViewModel(
        mission: MissionDraft(type: .photo, difficulty: .normal, repetitions: 1),
        matcher: MockPhotoMatcher(),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
