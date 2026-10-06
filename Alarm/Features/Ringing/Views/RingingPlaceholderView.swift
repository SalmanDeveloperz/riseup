//
//  RingingPlaceholderView.swift
//  RiseUp
//
//  LAYER: View (temporary; Phase 2 builds the real Ringing screen + missions)
//  WHAT:  Full-screen page shown after tapping "Start Mission" on a ringing alarm.
//  USED BY: ScreenFactory for FullScreenRoute.ringing(alarmID:).
//  VIEWMODEL: RingingPlaceholderViewModel.
//

import SwiftUI

struct RingingPlaceholderView: View {
    @State private var viewModel: RingingPlaceholderViewModel

    init(viewModel: RingingPlaceholderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Theme.Gradients.sunrise)
                // LEARN: `.bounce` with `.repeating` keeps the icon bouncing to grab attention.
                .symbolEffect(.bounce, options: .repeating)

            if let alarm = viewModel.alarm {
                BigClockText(hour: alarm.hour, minute: alarm.minute, size: 80)
                Text(alarm.displayTitle)
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Missions: " + alarm.sortedMissions.map(\.type.title).joined(separator: ", "))
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Text("Alarm not found")
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.riseCaption).foregroundStyle(Theme.Colors.danger)
            }

            Spacer()

            GlowCard {
                Text("Phase 2 puts the real mission here. For now, this button acts as “mission solved”.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Button("Complete mission (test)") {
                Task { await viewModel.completeMission() }
            }
            .buttonStyle(.neon)
            .disabled(viewModel.isCompleting)

            Button("Close without finishing") {
                viewModel.closeWithoutFinishing()
            }
            .buttonStyle(.ghost)
        }
        .padding(Theme.Spacing.lg)
        .appBackground()
        // LEARN: `.onAppear` runs synchronous setup once the view is on screen.
        .onAppear { viewModel.load() }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    RingingPlaceholderView(viewModel: RingingPlaceholderViewModel(
        alarmID: UUID(),
        repository: dependencies.alarmRepository,
        scheduler: dependencies.alarmScheduler,
        coordinator: AppCoordinator()
    ))
}
