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
//    → USES:     MissionCounterRing, SimulateSensorButton (shared with Steps and Squats)
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

            MissionCounterRing(
                progress: viewModel.progress,
                remaining: viewModel.remaining,
                caption: "shakes left",
                systemImage: "iphone.radiowaves.left.and.right",
                trigger: viewModel.count
            )

            Text("Hold your phone tight and shake it hard!")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            // The Simulator has no motion sensor: offer a button so the mission can be tested.
            if viewModel.canSimulate {
                SimulateSensorButton(title: "Simulate shake (Simulator only)") { viewModel.registerShake() }
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
