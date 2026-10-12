//
//  SquatMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15f: Squats)
//  WHAT:  How to hold the phone, and a ring counting down the squats left.
//  VIEWMODEL: SquatMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .squat)
//    → USES:     MissionCounterRing, SimulateSensorButton
//

import SwiftUI

struct SquatMissionView: View {
    @State private var viewModel: SquatMissionViewModel

    init(viewModel: SquatMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            MissionProgressHeader(type: .squat, done: viewModel.count, total: viewModel.target)

            Spacer(minLength: 0)

            MissionCounterRing(
                progress: viewModel.progress,
                remaining: viewModel.remaining,
                caption: "squats left",
                systemImage: "figure.strengthtraining.functional",
                trigger: viewModel.count
            )

            VStack(spacing: Theme.Spacing.xs) {
                Text("Hold the phone against your chest")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Squat all the way down, then stand up. Each one counts when you come back up.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            if viewModel.canSimulate {
                SimulateSensorButton(title: "Simulate squat (Simulator only)") { viewModel.registerSquat() }
            }
        }
        .onAppear { viewModel.start() }      // → motion sensor on
        .onDisappear { viewModel.stop() }    // → motion sensor off
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.count)
    }
}

#Preview {
    SquatMissionView(viewModel: SquatMissionViewModel(
        mission: MissionDraft(type: .squat, difficulty: .normal, repetitions: 10),
        detector: MockSquatDetector(),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
