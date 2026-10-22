//
//  MissionCounterRing.swift
//  RiseUp
//
//  LAYER: View (reusable piece shared by the counting missions)
//  WHAT:  A big gradient progress ring with an animated icon and "N shakes/steps/squats left".
//  DATA:  none (plain values in, pixels out).
//
//  CONNECTIONS:
//    ← USED BY: ShakeMissionView, StepsMissionView, SquatMissionView
//
//  WHY one shared view: three missions show the same "count down to zero" ring. Writing it
//  once means a design change (thicker ring, new font) happens in ONE place.
//

import SwiftUI

struct MissionCounterRing: View {
    /// 0…1, how much is done.
    let progress: Double
    /// The big number in the middle.
    let remaining: Int
    /// "shakes left", "steps left"…
    let caption: String
    let systemImage: String
    /// Changes every time progress is made → the icon wiggles.
    let trigger: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.surfaceRaised, lineWidth: 18)
            // LEARN: `.trim(from:to:)` draws only part of a shape: here, the done fraction.
            // Rotating by −90° makes it start at 12 o'clock instead of 3 o'clock.
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Theme.Gradients.brand, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.Colors.accent.opacity(0.6), radius: 12)
                .animation(.spring(duration: 0.3), value: progress)

            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.Gradients.brand)
                    // LEARN: `.symbolEffect(.wiggle, value:)` wiggles every time the value changes.
                    .symbolEffect(.wiggle, value: trigger)
                Text("\(remaining)")
                    .font(.riseClock(size: 64))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: remaining)
                Text(caption)
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: 260, height: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) \(caption)")
    }
}

/// The "Simulate … (Simulator only)" button the counting missions show when there's no sensor.
struct SimulateSensorButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "hand.tap.fill")
        }
        .buttonStyle(.ghost)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.xl) {
        MissionCounterRing(progress: 0.3, remaining: 21, caption: "steps left", systemImage: "figure.walk", trigger: 0)
        SimulateSensorButton(title: "Simulate a step (Simulator only)") {}
    }
    .padding()
    .appBackground()
}
