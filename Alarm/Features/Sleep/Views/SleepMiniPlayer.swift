//
//  SleepMiniPlayer.swift
//  RiseUp
//
//  LAYER: View (the sleep-sound mini player above the tab bar, #39)
//  WHAT:  [🌧] Rain + Ocean          ⏸  ✕
//              Stops in 23:41
//         Tap the bar → the full mixer. ⏸/▶ pauses. ✕ stops everything (the bar then disappears).
//  VIEWMODEL: SleepMiniPlayerViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY:  ScreenFactory.makeSleepMiniPlayer() ← RootView `.sleepMiniPlayer(isVisible:)`
//    → ACTIONS:   viewModel.open / togglePause / stop → SleepSoundPlayer, AppCoordinator
//
//  LEARN: iOS 26's `tabViewBottomAccessory` is the spot Apple Music uses for its mini player: a glass
//  bar that sits on the tab bar, on every tab. iOS draws the glass; we only give it the content.
//

import SwiftUI

struct SleepMiniPlayer: View {
    @State private var viewModel: SleepMiniPlayerViewModel
    /// `.inline` = squeezed next to a minimised tab bar (show less); `.expanded` = full width.
    /// nil = not inside a tab bar accessory (the iOS 26.0 fallback below).
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    init(viewModel: SleepMiniPlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isCompact: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                viewModel.open()                             // → Now Playing sheet (volumes, timer)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: viewModel.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.Colors.onAccent)
                        .frame(width: 32, height: 32)
                        .background(Theme.Gradients.night, in: .circle)
                        // LEARN: `.symbolEffect(.pulse)` gently fades the icon in and out: "this is playing".
                        .symbolEffect(.pulse, options: .repeating, isActive: viewModel.isPlaying)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if !isCompact { subtitle }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sleep sounds: \(viewModel.title)")
            .accessibilityHint("Opens the mixer and sleep timer")

            Button {
                viewModel.togglePause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isPlaying ? "Pause sleep sounds" : "Play sleep sounds")

            if !isCompact {
                Button {
                    viewModel.stop()                         // → everything stops, the bar goes away
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop sleep sounds")
            }
        }
        .padding(.leading, Theme.Spacing.sm)
        .padding(.trailing, Theme.Spacing.xs)
        .sensoryFeedback(.selection, trigger: viewModel.isPlaying)
    }

    /// "Stops in 23:41" (counting down by itself), "Paused · stops in 23:41", "Paused", or a hint.
    /// (The sleep timer keeps running while paused, see SleepSoundPlayer.pause.)
    @ViewBuilder
    private var subtitle: some View {
        Group {
            let prefix = viewModel.isPlaying ? "" : "Paused · "
            if let end = viewModel.timerEndsAt {
                // LEARN: `Text(date, style: .timer)` counts down live, without any code running every second.
                Text("\(prefix)\(viewModel.isPlaying ? "Stops" : "stops") in \(Text(end, style: .timer))")
                    .monospacedDigit()
            } else if !viewModel.isPlaying {
                Text("Paused")
            } else {
                Text("Sleep sounds · tap for mixer")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
        .lineLimit(1)
    }
}

// MARK: - Putting it on the tab bar

extension View {
    /// Shows `content` as the tab bar's mini player while `isVisible` is true.
    /// ← USED BY: RootView (on the TabView)
    ///
    /// WHY two ways: hiding the accessory (`isEnabled:`) needs iOS 26.1. RiseUp also runs on 26.0,
    /// where we float the same bar just above the tab bar ourselves, in Apple's glass.
    func sleepMiniPlayer<Content: View>(isVisible: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(SleepMiniPlayerPlacement(isVisible: isVisible, player: content))
    }
}

private struct SleepMiniPlayerPlacement<Player: View>: ViewModifier {
    let isVisible: Bool
    let player: () -> Player

    func body(content: Content) -> some View {
        // LEARN: `#available` picks code by the iPhone's iOS version at run time.
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isVisible) { player() }
        } else {
            content.overlay(alignment: .bottom) {
                if isVisible {
                    player()
                        .padding(.vertical, Theme.Spacing.xs)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, 62)                // just above the tab bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: isVisible)
        }
    }
}

#Preview {
    SleepMiniPlayer(viewModel: SleepMiniPlayerViewModel(player: MockSleepSoundPlayer(), coordinator: AppCoordinator()))
        .padding()
        .appBackground()
}
