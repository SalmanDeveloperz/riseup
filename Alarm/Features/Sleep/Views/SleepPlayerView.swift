//
//  SleepPlayerView.swift
//  RiseUp
//
//  LAYER: View (Screen #20 Now Playing sheet)
//  WHAT:  Big play/pause · countdown ring for the sleep timer · timer chips ·
//         a volume slider per sound · Stop.
//  VIEWMODEL: SleepPlayerViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: SheetRoute.sleepPlayer)
//    ← OPENED BY: SleepView's "now playing" bar → SleepViewModel.openPlayer()
//    → Done / Stop → viewModel → AppCoordinator.dismissSheet()
//

import SwiftUI

struct SleepPlayerView: View {
    @State private var viewModel: SleepPlayerViewModel

    init(viewModel: SleepPlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    playButton
                    timerSection
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.sounds) { sound in
                            volumeRow(sound)
                        }
                    }
                    Button("Stop all sounds", systemImage: "stop.fill", role: .destructive) {
                        viewModel.stop()
                    }
                    .buttonStyle(.ghost)
                }
                .padding(Theme.Spacing.lg)
                .animation(.spring(duration: 0.35), value: viewModel.sounds)
            }
            .appBackground()
            .navigationTitle("Now playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.close() }
                }
            }
        }
        // WHY full height only: at half height the volume sliders were hidden below the fold
        // (found in the Simulator), and they're the main reason to open this sheet.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Play / pause + countdown

    private var playButton: some View {
        // LEARN: TimelineView redraws its content on a schedule (here every second), perfect
        // for a countdown. It doesn't run when the screen is off, so it costs nothing in bed.
        // `paused:` = no timer, no ticking (found in the review: it redrew every second for nothing).
        TimelineView(.animation(minimumInterval: 1, paused: viewModel.timerEndsAt == nil)) { context in
            ZStack {
                Circle()
                    .stroke(Theme.Colors.surfaceRaised, lineWidth: 8)
                if let end = viewModel.timerEndsAt, let minutes = viewModel.activeTimerChoice {
                    let total = Double(minutes * 60)
                    let left = max(0, end.timeIntervalSince(context.date))
                    Circle()
                        .trim(from: 0, to: left / total)
                        .stroke(Theme.Gradients.night, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: left)
                }
                VStack(spacing: Theme.Spacing.xs) {
                    Button {
                        viewModel.togglePause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.Colors.onAccent)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 96, height: 96)
                            .background(Theme.Gradients.night, in: .circle)
                            .shadow(color: Theme.Colors.accentCool.opacity(viewModel.isPlaying ? 0.6 : 0), radius: 20)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .sensoryFeedback(.impact, trigger: viewModel.isPlaying)
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                    if let end = viewModel.timerEndsAt {
                        Text(SleepPlayerViewModel.remainingText(until: end, now: context.date))
                            .font(.riseHeadline.monospacedDigit())
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
            }
            .frame(width: 200, height: 200)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sleep timer chips

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SettingsSectionHeader(title: "Sleep timer")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(viewModel.timerChoices, id: \.self) { minutes in
                    let isOn = viewModel.activeTimerChoice == minutes
                    Button {
                        viewModel.chooseTimer(minutes)       // → player.startTimer / cancelTimer
                    } label: {
                        Text("\(minutes)m")
                            .font(.riseCaption.weight(.semibold))
                            .foregroundStyle(isOn ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isOn ? AnyShapeStyle(Theme.Gradients.night) : AnyShapeStyle(Theme.Colors.surface),
                                        in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("\(minutes) minutes")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text(viewModel.timerEndsAt == nil
                 ? "Sounds play until you stop them, or until your alarm rings."
                 : "Sounds fade out gently in the last 30 seconds. Tap the chip again to cancel.")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .sensoryFeedback(.selection, trigger: viewModel.activeTimerChoice)
    }

    // MARK: - Volume row

    private func volumeRow(_ sound: SleepSound) -> some View {
        GlowCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: sound.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Gradients.night)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(sound.title)
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    // LEARN: a custom Binding reads/writes through the ViewModel instead of a
                    // stored property. `onEditingChanged` tells us when the finger lifts.
                    Slider(
                        value: Binding(
                            get: { viewModel.volume(of: sound) },
                            set: { viewModel.setVolume($0, for: sound) }
                        ),
                        in: 0...1,
                        onEditingChanged: { isEditing in
                            if !isEditing { viewModel.saveVolumes() }
                        }
                    )
                    .tint(Theme.Colors.accentCool)
                    .accessibilityLabel("\(sound.title) volume")
                }
                Button {
                    viewModel.remove(sound)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(sound.title)")
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    dependencies.sleepSounds.toggle(.rain)
    dependencies.sleepSounds.toggle(.fire)
    return Color.black.sheet(isPresented: .constant(true)) {
        SleepPlayerView(viewModel: SleepPlayerViewModel(
            player: dependencies.sleepSounds,
            settings: dependencies.settings,
            coordinator: AppCoordinator()
        ))
    }
}
