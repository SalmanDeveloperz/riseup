//
//  OnboardingView.swift
//  RiseUp
//
//  LAYER: View (Screens #1–#4, one full-screen flow)
//  WHAT:  Four pages that slide left/right:
//           1. Welcome     – animated sun, what RiseUp does
//           2. Goal        – "What brings you here?" (picks the suggested mission)
//           3. Permission  – why alarms need permission, then the system popup
//           4. First alarm – time wheel, repeat days, suggested mission, "Create my alarm"
//  VIEWMODEL: OnboardingViewModel.
//
//  CONNECTIONS:
//    RootView (first launch) → AppCoordinator.presentOnboarding() → fullScreen = .onboarding
//      → ScreenFactory.makeScreen(for: .onboarding) → this view
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.openURL) private var openURL
    /// To re-check the permission when the user comes back from the Settings app.
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            topBar

            // LEARN: `.id(page)` makes each page a NEW view, so `.transition` animates the
            // old one out and the new one in (a slide), instead of morphing one into the other.
            Group {
                switch viewModel.page {
                case .welcome: welcomePage
                case .goal: goalPage
                case .permission: permissionPage
                case .firstAlarm: firstAlarmPage
                }
            }
            .id(viewModel.page)
            .transition(.asymmetric(
                insertion: .move(edge: viewModel.movedForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: viewModel.movedForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .frame(maxHeight: .infinity)
        }
        .padding(Theme.Spacing.lg)
        .appBackground()
        .animation(.spring(duration: 0.45), value: viewModel.page)
        .sensoryFeedback(.selection, trigger: viewModel.page)
        .onChange(of: scenePhase) {
            if scenePhase == .active { viewModel.refreshPermission() }   // back from Settings?
        }
        .alert("First alarm", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Top bar (back · page dots · skip)

    private var topBar: some View {
        HStack {
            Button {
                viewModel.back()
            } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .opacity(viewModel.page == .welcome ? 0 : 1)
            .disabled(viewModel.page == .welcome)
            .accessibilityLabel("Back")

            Spacer()
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(OnboardingViewModel.Page.allCases, id: \.self) { page in
                    Capsule()
                        .fill(page == viewModel.page ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised))
                        .frame(width: page == viewModel.page ? 24 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Spacer()

            Button("Skip") { viewModel.finish() }       // → onboarding done, nothing created
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - 1. Welcome

    private var welcomePage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            AppLogo(isBreathing: true)                      // the same picture as the Home Screen icon
            VStack(spacing: Theme.Spacing.xs) {
                Text("RiseUp")
                    .font(.riseLargeTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("The alarm you can't sleep through.")
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                feature("bolt.fill", "Missions wake your brain: maths, memory, steps, photos…")
                feature("lock.fill", "Pressing Stop doesn't work. Backups ring until you're up")
                feature("speaker.wave.3.fill", "Rings in Silent mode, Focus, even when closed")
            }
            Spacer()
            Button("Get started") { viewModel.next() }
                .buttonStyle(.neon)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Gradients.sunrise)
                .frame(width: 28)
            Text(text)
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    // MARK: - 2. Goal

    private var goalPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            pageTitle("What brings you here?", "We'll suggest the best mission for you.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.sm), GridItem(.flexible(), spacing: Theme.Spacing.sm)],
                      spacing: Theme.Spacing.sm) {
                ForEach(WakeGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
            Spacer()
            Button("Continue") { viewModel.next() }
                .buttonStyle(.neon)
                .disabled(viewModel.goal == nil)
        }
    }

    private func goalCard(_ goal: WakeGoal) -> some View {
        let isOn = viewModel.goal == goal
        return Button {
            viewModel.choose(goal)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: goal.systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised),
                                in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                Text(goal.title)
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline), lineWidth: isOn ? 2 : 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - 3. Permission

    private var permissionPage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: viewModel.permission == .authorized ? "checkmark.seal.fill" : "alarm.waves.left.and.right.fill")
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(viewModel.permission == .authorized ? AnyShapeStyle(Theme.Gradients.success) : AnyShapeStyle(Theme.Gradients.sunrise))
                .contentTransition(.symbolEffect(.replace))
            pageTitle("Let RiseUp ring", "iOS will ask if RiseUp may schedule alarms. Please tap “Allow”: without it, no alarm can ring.", centered: true)

            switch viewModel.permission {
            case .authorized:
                Label("Alarms allowed", systemImage: "checkmark.circle.fill")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.success)
            case .denied:
                Text("Alarms are switched off for RiseUp. Turn them on in Settings → RiseUp → Alarms.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.danger)
                    .multilineTextAlignment(.center)
            case .notDetermined:
                EmptyView()
            }
            Spacer()

            switch viewModel.permission {
            case .notDetermined:
                Button("Allow alarms") {
                    Task { await viewModel.allowAlarms() }      // → system popup
                }
                .buttonStyle(.neon)
                .disabled(viewModel.isWorking)
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.neon)
                Button("Continue anyway") { viewModel.next() }
                    .buttonStyle(.ghost)
            case .authorized:
                Button("Continue") { viewModel.next() }
                    .buttonStyle(.neon)
            }
        }
    }

    // MARK: - 4. First alarm

    private var firstAlarmPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                pageTitle("Your first alarm", "You can change everything later.")

                GlowCard(isGlowing: true) {
                    VStack(spacing: Theme.Spacing.xs) {
                        DatePicker("Alarm time", selection: $viewModel.time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, maxHeight: 160)
                            .clipped()
                        TimelineView(.everyMinute) { _ in
                            Text(viewModel.ringsInText(now: .now))
                                .font(.riseHeadline)
                                .foregroundStyle(Theme.Gradients.sunrise)
                        }
                    }
                }

                GlowCard {
                    RepeatDaysPicker(selection: $viewModel.repeatDays, onPreset: { viewModel.repeatDays = $0 })
                }

                missionToggle
            }
        }
        .scrollIndicators(.hidden)
        // WHY safeAreaInset: the buttons stay pinned and visible on small iPhones while the
        // cards above scroll (same fix as the Quick Alarm sheet).
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.xs) {
                Button {
                    Task { await viewModel.createAlarm() }       // → database → AlarmKit → close
                } label: {
                    if viewModel.isWorking {
                        ProgressView().tint(Theme.Colors.textPrimary)
                    } else {
                        Label("Create my alarm", systemImage: "alarm.fill")
                    }
                }
                .buttonStyle(.neon)
                .disabled(viewModel.isWorking)

                Button("Skip for now") { viewModel.finish() }
                    .buttonStyle(.ghost)
            }
            .padding(.top, Theme.Spacing.sm)
        }
    }

    private var missionToggle: some View {
        let mission = viewModel.suggestedMission
        return GlowCard(isGlowing: viewModel.addsMission) {
            Toggle(isOn: $viewModel.addsMission) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: mission.type.systemImage)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Theme.Gradients.sunrise, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a \(mission.type.title) mission")
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Suggested for you · \(mission.summary)")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .toggleStyle(.neon)
        }
    }

    // MARK: - Shared

    private func pageTitle(_ title: String, _ subtitle: String, centered: Bool = false) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.riseLargeTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    OnboardingView(viewModel: OnboardingViewModel(
        repository: dependencies.alarmRepository,
        scheduler: dependencies.alarmScheduler,
        settings: dependencies.settings,
        coordinator: AppCoordinator()
    ))
}
