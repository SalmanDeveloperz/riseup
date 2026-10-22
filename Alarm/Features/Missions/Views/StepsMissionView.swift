//
//  StepsMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15e: Steps)
//  WHAT:  A ring counting down the steps left, and a nudge to leave the bedroom.
//  VIEWMODEL: StepsMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .steps)
//    → USES:     MissionCounterRing, SimulateSensorButton
//

import SwiftUI

struct StepsMissionView: View {
    @State private var viewModel: StepsMissionViewModel

    init(viewModel: StepsMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            MissionProgressHeader(type: .steps, done: viewModel.steps, total: viewModel.target)

            Spacer(minLength: 0)

            MissionCounterRing(
                progress: viewModel.progress,
                remaining: viewModel.remaining,
                caption: "steps left",
                systemImage: "figure.walk",
                trigger: viewModel.steps
            )

            VStack(spacing: Theme.Spacing.xs) {
                Text("Get up and walk!")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                // WHY this note: the pedometer reports in batches, so the number can pause for
                // a few seconds and then jump. Without it, users think it's broken.
                Text("Keep the phone with you. Steps can take a few seconds to appear.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            if viewModel.canSimulate {
                SimulateSensorButton(title: "Simulate 5 steps (Simulator only)") { viewModel.simulateSteps() }
            }
        }
        .onAppear { viewModel.start() }      // → pedometer on (asks permission the first time)
        .onDisappear { viewModel.stop() }    // → pedometer off
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.steps)
    }
}

#Preview {
    StepsMissionView(viewModel: StepsMissionViewModel(
        mission: MissionDraft(type: .steps, difficulty: .normal, repetitions: 30),
        counter: MockStepCounter(),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
