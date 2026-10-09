//
//  ShakeMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15c: Shake)
//  WHAT:  A big progress ring counting down the shakes left, with a wiggling phone icon.
//  VIEWMODEL: ShakeMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .shake)
//    → starts/stops the motion sensor when the screen appears/disappears
//

import SwiftUI

struct ShakeMissionView: View {
    @State private var viewModel: ShakeMissionViewModel

    init(viewModel: ShakeMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            MissionProgressHeader(type: .shake, done: viewModel.count, total: viewModel.target)

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(Theme.Colors.surfaceRaised, lineWidth: 18)
                // LEARN: `.trim(from:to:)` draws only part of a shape: here, the done fraction.
                // Rotating by −90° makes it start at 12 o'clock instead of 3 o'clock.
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(Theme.Gradients.sunrise, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.Colors.neonPink.opacity(0.6), radius: 12)
                    .animation(.spring(duration: 0.3), value: viewModel.count)

                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.Gradients.sunrise)
                        // LEARN: `.symbolEffect(.wiggle, value:)` wiggles every time the value changes.
                        .symbolEffect(.wiggle, value: viewModel.count)
                    Text("\(viewModel.remaining)")
                        .font(.riseClock(size: 64))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: viewModel.remaining)
                    Text("shakes left")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .frame(width: 260, height: 260)

            Text("Hold your phone tight and shake it hard!")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            // The Simulator has no motion sensor: offer a button so the mission can be tested.
            if !viewModel.isSensorAvailable {
                Button("Simulate shake (no sensor)") { viewModel.registerShake() }
                    .buttonStyle(.ghost)
            }
        }
        .onAppear { viewModel.start() }      // → motion sensor on
        .onDisappear { viewModel.stop() }    // → motion sensor off (battery)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.count)
    }
}

#Preview {
    ShakeMissionView(viewModel: ShakeMissionViewModel(
        mission: MissionDraft(type: .shake, difficulty: .normal, repetitions: 30),
        detector: MockShakeDetector(),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
