//
//  RingingView.swift
//  RiseUp
//
//  LAYER: View (Screens #14 Ringing / #15 Missions / #16 Success, one full-screen flow)
//  WHAT:  Switches between three looks depending on `viewModel.phase`:
//           .ringing → pulsing clock, alarm title, Start Mission / I'm up / Snooze
//           .mission → the current mission (Math/Typing/Shake) + "alarm paused" status
//           .success → SuccessView with confetti
//  VIEWMODEL: RingingViewModel.
//
//  CONNECTIONS (the paths to this screen):
//    lock screen "Start Mission" → StartMissionIntent → AlarmLaunchRouter → RootView.onChange
//    app opened while an alarm rings → RootView sync → AlarmSyncService.ringingAlarmID
//    Alarm List "Finish waking up" banner → AlarmListViewModel.resumeWakeUp
//      → all three call AppCoordinator.presentRinging(alarmID:)
//      → coordinator.fullScreen = .ringing(...) → RootView .fullScreenCover → ScreenFactory → this view
//

import SwiftUI

struct RingingView: View {
    @State private var viewModel: RingingViewModel
    /// Drives the breathing glow behind the clock.
    @State private var isPulsing = false
    /// LEARN: the iPhone's "Reduce Motion" setting. When on, we skip endless pulsing.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Developer mode (Debug builds only) → shows "Close (debug)". → DeveloperTools.swift
    @Environment(\.showsDeveloperTools) private var showsDeveloperTools
    /// LEARN: is RiseUp in front (`.active`) or in the background? → the keep-alive (see RingingViewModel)
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: RingingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            background
            content
                .padding(Theme.Spacing.lg)
        }
        .onAppear { viewModel.start() }                 // → silence iOS, play our sound, open record
        // WHY always dark (#35): the whole wake-up happens on a night-sky wallpaper; light-mode text
        // (dark ink) would vanish on it. LEARN: inside a full-screen cover this only affects the cover.
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) {
            viewModel.appActivityChanged(isActive: scenePhase == .active)   // → hold the chain or let iOS ring
        }
        .alert("Alarm", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// The alarm's wallpaper (#32), alive and getting more energetic the longer it rings.
    ///   ringing → full wallpaper + ramp · mission → dimmed, so the task stands out · success → full energy
    @ViewBuilder
    private var background: some View {
        if let info = viewModel.info {
            let energy: WallpaperEnergy = {
                if case .success = viewModel.phase { return .fixed(1) }      // celebrate!
                return .ramp(start: viewModel.ringStartedAt, duration: RingingViewModel.wallpaperRampSeconds)
            }()
            WallpaperView(wallpaper: info.wallpaper, photo: viewModel.wallpaperPhoto,
                          energy: energy, showsScrim: true)
                .ignoresSafeArea()
                .overlay {
                    // WHY dim during missions: maths and typing need focus; the wallpaper stays as a hint.
                    Color.black.opacity(isInMission ? 0.72 : 0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.4), value: isInMission)
                }
        } else {
            AppBackground()
        }
    }

    private var isInMission: Bool {
        if case .mission = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .ringing:
            if let info = viewModel.info {
                ringing(info)
            } else {
                missingAlarm
            }
        case .mission:
            if let mission = viewModel.currentMission {
                missionStage(mission)
            }
        case .success(let summary):
            SuccessView(
                summary: summary,
                mood: viewModel.mood,
                onMood: { viewModel.setMood($0) },               // → saved with this wake-up
                onClose: { viewModel.close() }
            )
        }
    }

    // MARK: - Ringing

    private func ringing(_ info: RingingViewModel.RingInfo) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            #if DEBUG
            if showsDeveloperTools {
                HStack {
                    Spacer()
                    Button("Close (debug)") { viewModel.debugClose() }
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            #endif

            Spacer()

            Text(info.title.uppercased())
                .font(.riseHeadline)
                .tracking(2)
                .foregroundStyle(Theme.Colors.accent)

            // The live clock, with a glow that "breathes" like a heartbeat.
            TimelineView(.everyMinute) { context in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                BigClockText(hour: parts.hour ?? 0, minute: parts.minute ?? 0, size: 96)
            }
            .clockHalo()                                  // readable on any wallpaper
            .background {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.35))
                    .blur(radius: 60)
                    .scaleEffect(isPulsing ? 1.25 : 0.85)
            }
            .onAppear {
                guard !reduceMotion else { return }     // calm, still glow for motion-sensitive users
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { isPulsing = true }
            }

            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            volumeHint

            if info.missions.isEmpty {
                Button {
                    Task { await viewModel.dismiss() }     // → success
                } label: {
                    Label("I'm up", systemImage: "sun.max.fill")
                }
                .buttonStyle(.neon)

                if viewModel.canSnooze {
                    Button {
                        Task { await viewModel.snooze() }  // → rings again in N minutes
                    } label: {
                        Text("Snooze \(info.snoozeMinutes) min · \(viewModel.snoozesLeft) left")
                    }
                    .buttonStyle(.ghost)
                    .disabled(viewModel.isSnoozing)
                } else if info.isSnoozeEnabled {
                    Text("No snoozes left. Time to get up!")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            } else {
                // Which missions are waiting, as small chips.
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(info.missions) { mission in
                        Label(mission.type.title, systemImage: mission.type.systemImage)
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Colors.surfaceRaised, in: .capsule)
                    }
                }
                Button {
                    viewModel.startMissions()              // → first mission
                } label: {
                    Label("Start Mission", systemImage: "bolt.fill")
                }
                .buttonStyle(.neon)
                Text("The alarm goes quiet while you work on it.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .sensoryFeedback(.warning, trigger: viewModel.snoozeCount)
    }

    /// "Turn the volume up": shown while the media volume is low (our sound plays at that volume).
    /// LEARN: `TimelineView(.periodic(…))` re-reads `isVolumeLow` every second; iOS doesn't tell
    /// SwiftUI when the volume changes, so we look again regularly.
    private var volumeHint: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if viewModel.isVolumeLow {
                Label("Your volume is low. Turn it up to hear your alarm.", systemImage: "speaker.wave.1.fill")
                    .font(.riseCaption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.ultraThinMaterial, in: .capsule)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Mission

    private func missionStage(_ mission: MissionDraft) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text(viewModel.missionNumberText)
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Label(viewModel.isQuiet ? "Alarm paused" : "Alarm ringing",
                      systemImage: viewModel.isQuiet ? "speaker.slash.fill" : "speaker.wave.3.fill")
                    .font(.riseCaption)
                    .foregroundStyle(viewModel.isQuiet ? Theme.Colors.textTertiary : Theme.Colors.accent)
            }

            if viewModel.isIdleWarning {
                Label("Still there? The alarm is back. Keep going to quiet it.", systemImage: "exclamationmark.triangle.fill")
                    .font(.riseHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.danger.opacity(0.85), in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            MissionView(
                mission: mission,
                services: viewModel.missionServices,
                onInteraction: { viewModel.userInteracted() },   // → keeps the alarm quiet
                onComplete: { viewModel.missionFinished() },     // → next mission or success
                onReplaced: { viewModel.currentMissionReplaced() } // → normal 15 s quiet time
            )
            // WHY `.id`: a new mission = a brand-new mission view with fresh state.
            .id(mission.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        // Any tap anywhere counts as "still awake".
        .simultaneousGesture(TapGesture().onEnded { viewModel.userInteracted() })
        .animation(.spring(duration: 0.4), value: viewModel.phase)
        .animation(.easeInOut, value: viewModel.isIdleWarning)
    }

    // MARK: - Missing alarm

    private var missingAlarm: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Text("This alarm no longer exists.")
                .font(.riseTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Button("Close") { viewModel.close() }.buttonStyle(.neon)
            Spacer()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    let alarm = WakeAlarm(hour: 6, minute: 30, label: "Gym")
    alarm.missions = [MissionConfig(type: .math, difficulty: .easy, repetitions: 2)]
    try? dependencies.alarmRepository.insert(alarm)
    return RingingView(viewModel: RingingViewModel(
        alarmID: alarm.id,
        repository: dependencies.alarmRepository,
        records: dependencies.wakeRecordRepository,
        scheduler: dependencies.alarmScheduler,
        audio: dependencies.audio,
        timeAnnouncer: dependencies.timeAnnouncer,
        sleepSounds: dependencies.sleepSounds,
        settings: dependencies.settings,
        wallpaperStore: dependencies.wallpaperStore,
        customSounds: dependencies.customSounds,
        missionServices: dependencies.missionServices,
        coordinator: AppCoordinator()
    ))
}
