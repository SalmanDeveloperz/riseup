//
//  SleepView.swift
//  RiseUp
//
//  LAYER: View (Screen #19 Sleep sounds, the Sleep tab's root)
//  WHAT:  Moonlit header · "now playing" bar · sound tiles by category (tap to mix) ·
//         bedtime reminder card.
//  VIEWMODEL: SleepViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeRoot(for: .sleep) (replaces the Phase 0 "coming soon")
//    → Now playing bar → viewModel.openPlayer() → AppCoordinator → sheet (#20)
//

import SwiftUI

struct SleepView: View {
    @State private var viewModel: SleepViewModel
    /// Drives the slow "breathing" glow of the moon.
    @State private var isGlowing = false

    init(viewModel: SleepViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                           GridItem(.flexible(), spacing: Theme.Spacing.sm),
                           GridItem(.flexible(), spacing: Theme.Spacing.sm)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                ForEach(viewModel.categories) { category in
                    SettingsSectionHeader(title: category.title)
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                        ForEach(category.sounds) { sound in
                            tile(sound)
                        }
                    }
                }
                bedtimeCard
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Sleep")
        // LEARN: `safeAreaInset` pins a view to an edge AND shrinks the scroll area, so the
        // last tiles can still scroll out from under it (unlike a plain overlay).
        // WHY at the bottom (found in the Simulator): when the bar and the hint sat above the
        // grid, they pushed every tile down mid-tap, so the next tap hit the wrong sound.
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xs)
                .animation(.spring(duration: 0.35), value: viewModel.hasMix)
                .animation(.easeInOut, value: viewModel.message)
        }
    }

    /// Mini player (or "Play last mix"), with the hint message floating just above it.
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let message = viewModel.message {
                Label(message, systemImage: "info.circle.fill")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.warning)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.surfaceRaised, in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // LEARN: `.task(id:)` restarts when `id` changes, so a NEW hint gets its own
                    // full 4 seconds instead of vanishing on the old hint's timer.
                    .task(id: message) {
                        // Hide the hint after a few seconds.
                        try? await Task.sleep(for: .seconds(4))
                        viewModel.dismissMessage()
                    }
            }
            if viewModel.hasMix {
                nowPlayingBar
            } else if viewModel.canPlayLastMix {
                Button {
                    viewModel.playLastMix()
                } label: {
                    Label("Play last mix", systemImage: "play.fill")
                }
                .buttonStyle(.neon)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Theme.Gradients.night)
                .shadow(color: Theme.Colors.neonBlue.opacity(isGlowing ? 0.7 : 0.2), radius: isGlowing ? 26 : 8)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { isGlowing = true }
                }
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Drift off gently")
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Mix up to \(sleepMixMaxSounds) sounds. They keep playing when your phone is locked.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Now playing

    private var nowPlayingBar: some View {
        Button {
            viewModel.openPlayer()                           // → Now Playing sheet (#20)
        } label: {
            GlowCard(isGlowing: viewModel.isPlaying) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "waveform")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.Gradients.night)
                        .symbolEffect(.variableColor.iterative, isActive: viewModel.isPlaying)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.mixTitle)
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if let end = viewModel.timerEndsAt {
                            Text("Stops at \(end.formatted(date: .omitted, time: .shortened))")
                                .font(.riseCaption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        } else {
                            Text("Tap for volume and sleep timer")
                                .font(.riseCaption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        viewModel.togglePause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.Gradients.night, in: .circle)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                }
            }
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Sound tile

    private func tile(_ sound: SleepSound) -> some View {
        let isOn = viewModel.isActive(sound)
        return Button {
            viewModel.toggle(sound)                          // → SleepSoundPlayer
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: sound.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isOn ? AnyShapeStyle(Theme.Colors.textPrimary) : AnyShapeStyle(Theme.Gradients.night))
                    .frame(width: 56, height: 56)
                    .background(isOn ? AnyShapeStyle(Theme.Gradients.night) : AnyShapeStyle(Theme.Colors.surfaceRaised), in: .circle)
                    .shadow(color: isOn ? Theme.Colors.neonBlue.opacity(0.6) : .clear, radius: 12)
                    .symbolEffect(.pulse, isActive: isOn && viewModel.isPlaying)
                Text(sound.title)
                    .font(.riseCaption)
                    .foregroundStyle(isOn ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isOn ? AnyShapeStyle(Theme.Gradients.night) : AnyShapeStyle(Theme.Colors.hairline), lineWidth: isOn ? 2 : 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(sound.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Bedtime reminder

    private var bedtimeCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle(isOn: Binding(
                    get: { viewModel.reminderOn },
                    set: { isOn in Task { await viewModel.setReminder(isOn) } }    // → permission → schedule
                )) {
                    Label("Bedtime reminder", systemImage: "bed.double.fill")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .toggleStyle(.neon)

                if viewModel.reminderOn {
                    DatePicker("Remind me at", selection: $viewModel.bedtime, displayedComponents: .hourAndMinute)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tint(Theme.Colors.neonPink)
                }
                Text("A gentle nudge to put the phone down. Good mornings start the night before.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .animation(.easeInOut, value: viewModel.reminderOn)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        SleepView(viewModel: SleepViewModel(
            player: dependencies.sleepSounds,
            settings: dependencies.settings,
            reminder: dependencies.bedtimeReminder,
            coordinator: AppCoordinator()
        ))
    }
}
