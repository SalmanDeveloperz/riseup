//
//  WallpaperPreviewView.swift
//  RiseUp
//
//  LAYER: View (full-screen "Try it" for the Wallpaper Picker)
//  WHAT:  The wallpaper full screen with the Ringing screen's clock on top, exactly as it will look
//         at 6 a.m. The energy rises over 8 seconds so you can watch it "wake up".
//         "Use this wallpaper" / ✕.
//  DATA:  none (values in, closures out).
//
//  CONNECTIONS:
//    ← SHOWN BY: WallpaperPickerView `.fullScreenCover(item: $viewModel.previewing)`
//    → onUse / onClose → WallpaperPickerViewModel.use(_:) / previewing = nil
//

import SwiftUI

struct WallpaperPreviewView: View {
    let wallpaper: Wallpaper
    let photo: UIImage?
    let onUse: () -> Void
    let onClose: () -> Void

    /// When the preview opened: the energy ramp starts here.
    @State private var openedAt = Date.now
    private let rampSeconds: TimeInterval = 8

    var body: some View {
        ZStack {
            WallpaperView(wallpaper: wallpaper, photo: photo,
                          energy: .ramp(start: openedAt, duration: rampSeconds), showsScrim: true)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .accessibilityLabel("Close preview")
                    Spacer()
                    energyBadge
                }

                Spacer()

                // The Ringing screen's look, so you see exactly what you'll wake up to.
                Text(wallpaper.resolved().title.uppercased())
                    .font(.riseHeadline)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                TimelineView(.everyMinute) { context in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                    BigClockText(hour: parts.hour ?? 0, minute: parts.minute ?? 0, size: 96)
                        .shadow(color: .black.opacity(0.35), radius: 12)
                }
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.riseBody)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                if wallpaper == .surprise {
                    Text("Today it's \(wallpaper.resolved().title). Tomorrow, something new.")
                        .font(.riseCaption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Button(action: onUse) {
                    Label("Use this wallpaper", systemImage: "checkmark")
                }
                .buttonStyle(.neon)
            }
            .padding(Theme.Spacing.lg)
        }
        .statusBarHidden()
    }

    /// "Waking up… 60 %": shows the energy ramp the Ringing screen will use.
    private var energyBadge: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let level = WallpaperEnergy.ramp(start: openedAt, duration: rampSeconds).level(at: context.date)
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: level >= 1 ? "sun.max.fill" : "sunrise.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(level >= 1 ? "Wide awake" : "Waking up \(Int(level * 100)) %")
                    .monospacedDigit()
            }
            .font(.riseCaption.weight(.semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(minHeight: 36)
            .background(.ultraThinMaterial, in: .capsule)
            .onTapGesture { openedAt = .now }                // replay the wake-up
            .accessibilityLabel("Energy \(Int(level * 100)) percent. Tap to replay.")
        }
    }
}

#Preview {
    WallpaperPreviewView(wallpaper: .live(.synthwave), photo: nil, onUse: {}, onClose: {})
}
