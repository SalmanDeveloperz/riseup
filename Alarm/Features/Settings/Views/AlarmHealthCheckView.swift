//
//  AlarmHealthCheckView.swift
//  RiseUp
//
//  LAYER: View (Screen #28 "Why didn't my alarm ring?")
//  WHAT:  A big status header (all good / needs fixing) and one card per check, each with
//         a fix button where possible.
//  VIEWMODEL: AlarmHealthCheckViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: .alarmCheck)
//    → Fix buttons → viewModel.perform(...), or open the Settings app (openURL)
//

import SwiftUI
import UIKit

struct AlarmHealthCheckView: View {
    @State private var viewModel: AlarmHealthCheckViewModel
    @Environment(\.openURL) private var openURL
    /// WHY watch scenePhase: after "Open Settings" the user comes BACK to the app with a
    /// permission maybe switched on. Re-checking then shows the green tick right away.
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: AlarmHealthCheckViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                header
                ForEach(viewModel.checks) { check in
                    card(check)
                }
            }
            .padding(Theme.Spacing.lg)
            .animation(.spring(duration: 0.3), value: viewModel.checks.map(\.id))
        }
        .appBackground()
        .navigationTitle("Check my alarms")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { viewModel.refresh() }
        }
    }

    private var header: some View {
        GlowCard(isGlowing: true) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon(for: viewModel.overallStatus))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(color(for: viewModel.overallStatus))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(viewModel.headline)
                        .font(.riseTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("RiseUp checked your permissions and what iOS has scheduled.")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func card(_ check: AlarmHealthCheckViewModel.Check) -> some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: icon(for: check.status))
                        .font(.title3)
                        .foregroundStyle(color(for: check.status))
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(check.title)
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(check.detail)
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let fix = check.fix, let title = check.fixTitle {
                    Button(title) {
                        if fix == .openSettings {
                            // LEARN: this special URL opens RiseUp's own page in the Settings app.
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } else {
                            Task { await viewModel.perform(fix) }
                        }
                    }
                    .buttonStyle(check.status == .problem ? AnyButtonStyle(NeonButtonStyle()) : AnyButtonStyle(GhostButtonStyle()))
                    .disabled(viewModel.isWorking)
                }
            }
        }
    }

    private func icon(for status: AlarmHealthCheckViewModel.Status) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .info: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .problem: "xmark.octagon.fill"
        }
    }

    private func color(for status: AlarmHealthCheckViewModel.Status) -> Color {
        switch status {
        case .ok: Theme.Colors.success
        case .info: Theme.Colors.accentCool
        case .warning: Theme.Colors.warning
        case .problem: Theme.Colors.danger
        }
    }
}

/// Lets one `.buttonStyle(...)` call choose between two different style types.
///
/// LEARN: `.buttonStyle` needs ONE concrete type, so `condition ? .neon : .ghost` doesn't
/// compile (two different types). Wrapping both in a common type ("type erasure") fixes it.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init(_ style: some ButtonStyle) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        AlarmHealthCheckView(viewModel: AlarmHealthCheckViewModel(
            repository: dependencies.alarmRepository,
            scheduler: dependencies.alarmScheduler,
            sync: dependencies.alarmSync,
            stepCounter: dependencies.missionServices.steps,
            coordinator: AppCoordinator()
        ))
    }
}
