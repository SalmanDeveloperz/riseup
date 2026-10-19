//
//  ScenePlayerView.swift
//  RiseUp
//
//  LAYER: View (Screen #33 Scene Player, full screen, opened from the Wallpaper Picker)
//  WHAT:  The wallpaper full screen with its SOUND playing, like the real alarm will be:
//           • the clock on top (hide it with 👁 to see the whole scene)
//           • a now-playing card: sound name, where it's from, a little equalizer
//           • ♥ save · ⏮ previous · ▶︎/⏸ · ⏭ next · 👁 clock — or swipe left/right
//           • "Use wallpaper + sound" / "Wallpaper only"
//  VIEWMODEL: WallpaperPickerViewModel (shared with the picker: same playlist, bookmarks, choice).
//
//  CONNECTIONS:
//    ← SHOWN BY: WallpaperPickerView `.fullScreenCover(isPresented: $viewModel.isShowingPlayer)`
//    → controls → viewModel.next / previous / togglePlay / toggleSaved / use(withSound:) / closePlayer
//

import SwiftUI

struct ScenePlayerView: View {
    let viewModel: WallpaperPickerViewModel

    /// When the current scene appeared: its "wake-up" energy ramp starts here.
    @State private var sceneStart = Date.now
    /// 👁: hide the clock to see the whole scene.
    @State private var showsClock = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rampSeconds: TimeInterval = 8

    var body: some View {
        ZStack {
            if let wallpaper = viewModel.playing {
                WallpaperView(wallpaper: wallpaper, photo: viewModel.photo(for: wallpaper),
                              energy: .ramp(start: sceneStart, duration: rampSeconds), showsScrim: showsClock)
                    .ignoresSafeArea()
                    .id(wallpaper)                              // a new scene fades in (see transition)
                    .transition(.opacity)
            }

            VStack(spacing: Theme.Spacing.md) {
                topBar
                Spacer()
                if showsClock, let wallpaper = viewModel.playing {
                    clock(for: wallpaper)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                Spacer()
                nowPlayingCard
            }
            .padding(Theme.Spacing.lg)
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)                    // WHY: like the Ringing screen, it's drawn on a wallpaper
        // LEARN: a DragGesture that only cares where the finger ENDED: a quick swipe sideways.
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if value.translation.width < -60 { viewModel.next() }
            if value.translation.width > 60 { viewModel.previous() }
        })
        .animation(.easeInOut(duration: 0.45), value: viewModel.playerIndex)
        .animation(.spring(duration: 0.3), value: showsClock)
        .onChange(of: viewModel.playerIndex) { sceneStart = .now }    // replay the wake-up on each scene
        .sensoryFeedback(.selection, trigger: viewModel.playerIndex)
        .onDisappear { viewModel.stopSound() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            roundButton("xmark", label: "Close") { viewModel.closePlayer() }
            Spacer()
            Text(viewModel.playerPosition)
                .font(.riseCaption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: 36)
                .background(.ultraThinMaterial, in: .capsule)
        }
    }

    // MARK: - Clock (what the alarm will look like)

    private func clock(for wallpaper: Wallpaper) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(wallpaper.resolved().title.uppercased())
                .font(.riseHeadline)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))
            TimelineView(.everyMinute) { context in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                BigClockText(hour: parts.hour ?? 0, minute: parts.minute ?? 0, size: 88)
                    .shadow(color: .black.opacity(0.35), radius: 12)
            }
            Text("Swipe for more scenes")
                .font(.riseCaption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .clockHalo()                                      // readable on any wallpaper
    }

    // MARK: - Now playing

    private var nowPlayingCard: some View {
        let wallpaper = viewModel.playing ?? .standard
        let sound = viewModel.sound(for: wallpaper)
        return VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: sound.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Theme.Gradients.brand, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(viewModel.hasSignatureSound(wallpaper) ? sound.subtitle : "Your alarm's sound")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Equalizer(isPlaying: viewModel.isSoundPlaying && !reduceMotion)
            }

            HStack {
                controlButton(viewModel.isSaved(wallpaper) ? "heart.fill" : "heart",
                              label: viewModel.isSaved(wallpaper) ? "Remove from Saved" : "Save",
                              tint: viewModel.isSaved(wallpaper) ? Theme.Colors.accent : Theme.Colors.textPrimary) {
                    viewModel.toggleSaved()
                }
                Spacer()
                controlButton("backward.fill", label: "Previous scene") { viewModel.previous() }
                Spacer()
                Button {
                    viewModel.togglePlay()
                } label: {
                    Image(systemName: viewModel.isSoundPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.Colors.onAccent)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 64, height: 64)
                        .background(Theme.Gradients.brand, in: .circle)
                        .shadow(color: Theme.Colors.accent.opacity(0.5), radius: 12)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(viewModel.isSoundPlaying ? "Pause sound" : "Play sound")
                Spacer()
                controlButton("forward.fill", label: "Next scene") { viewModel.next() }
                Spacer()
                controlButton(showsClock ? "eyes" : "eyes.inverse", label: showsClock ? "Hide clock" : "Show clock") {
                    showsClock.toggle()
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isSaved(wallpaper))

            if viewModel.hasSignatureSound(wallpaper) {
                Button {
                    Task { await viewModel.use(withSound: true) }   // → editor: wallpaper AND sound
                } label: {
                    Label("Use wallpaper + sound", systemImage: "checkmark")
                }
                .buttonStyle(.neon)
                Button("Wallpaper only") {
                    Task { await viewModel.use(withSound: false) }  // → editor: keeps the alarm's sound
                }
                .buttonStyle(.ghost)
            } else {
                Button {
                    Task { await viewModel.use(withSound: false) }
                } label: {
                    Label("Use this photo", systemImage: "checkmark")
                }
                .buttonStyle(.neon)
            }
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Pieces

    private func controlButton(_ systemImage: String, label: String, tint: Color = Theme.Colors.textPrimary,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func roundButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
        }
        .accessibilityLabel(label)
    }
}

/// Four little bars that dance while the sound plays.
/// LEARN: no audio analysis here: the bars move with smooth sine waves, which looks musical and costs nothing.
private struct Equalizer: View {
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    let level = isPlaying ? 0.35 + 0.65 * abs(sin(t * (2.5 + Double(i) * 0.7) + Double(i))) : 0.2
                    Capsule()
                        .fill(Theme.Gradients.brand)
                        .frame(width: 4, height: 22 * level)
                }
            }
            .frame(width: 28, height: 22, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
