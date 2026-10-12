//
//  MissionView.swift
//  RiseUp
//
//  LAYER: View (a "router" for missions)
//  WHAT:  Shows the right mission screen for a MissionDraft, and swaps in a Math mission
//         when a sensor/camera mission can't run (or the user gave up on it).
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: RingingView (real wake-up) and MissionPickerView ("Try it" practice)
//    → BUILDS:  Math / Typing / Memory / Shake / Steps / Squat / Photo / Barcode mission views
//               with their ViewModels
//    → onInteraction / onComplete are passed straight through to the mission ViewModel
//    → USES:    MissionServices (the sensors) handed down from AppDependencies
//
//  WHY a separate router view: both the Ringing screen and the "Try it" practice show
//  missions. Writing the `switch` once means a new mission type is added in ONE place.
//
//  IMPORTANT: give MissionView a different `.id(...)` for each mission (RingingView does).
//  WHY: two Math missions in a row would otherwise REUSE the first one's @State
//  ViewModel, and the second mission would start already solved.
//
//  THE SAFETY NET (`replacement`)
//  ──────────────────────────────
//  An alarm must never be impossible to turn off, and never free to skip:
//    • sensor missing / permission denied / registration damaged → Math, 3 normal problems
//    • "Can't match / can't find it?" after a few failed tries      → Math, 5 HARD problems
//

import SwiftUI

struct MissionView: View {
    let mission: MissionDraft
    let services: MissionServices
    let onInteraction: () -> Void
    let onComplete: () -> Void

    /// Non-nil → a Math mission is shown INSTEAD of `mission`.
    @State private var replacement: Replacement?

    /// Why the original mission was replaced, and with what.
    enum Replacement: Equatable {
        case unavailable   // the phone can't run this mission right now
        case gaveUp        // the user chose the harder way out

        var mission: MissionDraft {
            switch self {
            case .unavailable: MissionDraft(type: .math, difficulty: .normal, repetitions: 3)
            case .gaveUp: MissionDraft(type: .math, difficulty: .hard, repetitions: 5)
            }
        }

        var message: String {
            switch self {
            case .unavailable: "This mission can't run on this iPhone right now (sensor or camera not available or not allowed), so here's a Math mission instead."
            case .gaveUp: "OK! Solve these to prove you're awake."
            }
        }
    }

    var body: some View {
        if let replacement {
            VStack(spacing: Theme.Spacing.md) {
                Label(replacement.message, systemImage: "arrow.triangle.2.circlepath")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                MathMissionView(viewModel: MathMissionViewModel(
                    mission: replacement.mission, onInteraction: onInteraction, onComplete: onComplete))
            }
            .transition(.opacity)
        } else {
            original
        }
    }

    // LEARN: these two closures are handed to the sensor/camera missions. Calling one
    // changes `replacement` (@State), and SwiftUI redraws `body` with the Math branch above.
    private var useFallback: () -> Void { { replacement = .unavailable } }
    private var giveUp: () -> Void { { replacement = .gaveUp } }

    @ViewBuilder
    private var original: some View {
        switch mission.type {
        case .math:
            MathMissionView(viewModel: MathMissionViewModel(
                mission: mission, onInteraction: onInteraction, onComplete: onComplete))
        case .typing:
            TypingMissionView(viewModel: TypingMissionViewModel(
                mission: mission, onInteraction: onInteraction, onComplete: onComplete))
        case .memory:
            MemoryMissionView(viewModel: MemoryMissionViewModel(
                mission: mission, onInteraction: onInteraction, onComplete: onComplete))
        case .shake:
            ShakeMissionView(viewModel: ShakeMissionViewModel(
                mission: mission, detector: services.shake,
                onInteraction: onInteraction, onComplete: onComplete, onUnavailable: useFallback))
        case .steps:
            StepsMissionView(viewModel: StepsMissionViewModel(
                mission: mission, counter: services.steps,
                onInteraction: onInteraction, onComplete: onComplete, onUnavailable: useFallback))
        case .squat:
            SquatMissionView(viewModel: SquatMissionViewModel(
                mission: mission, detector: services.squat,
                onInteraction: onInteraction, onComplete: onComplete, onUnavailable: useFallback))
        case .photo:
            PhotoMissionView(viewModel: PhotoMissionViewModel(
                mission: mission, matcher: services.photoMatcher,
                onInteraction: onInteraction, onComplete: onComplete,
                onUnavailable: useFallback, onGiveUp: giveUp))
        case .barcode:
            BarcodeMissionView(viewModel: BarcodeMissionViewModel(
                mission: mission,
                onInteraction: onInteraction, onComplete: onComplete,
                onUnavailable: useFallback, onGiveUp: giveUp))
        }
    }
}

/// "MATH · 2 / 3" with a gradient progress bar. Shared by all mission screens.
struct MissionProgressHeader: View {
    let type: MissionType
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Label(type.title.uppercased(), systemImage: type.systemImage)
                    .font(.riseCaption)
                    .tracking(1)
                    .foregroundStyle(Theme.Colors.neonPink)
                Spacer()
                Text("\(done) / \(total)")
                    .font(.riseHeadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .contentTransition(.numericText())
            }
            // LEARN: a progress bar is just two capsules: a dim track + a gradient fill
            // whose width is `fraction × available width` (GeometryReader gives the width).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceRaised)
                    Capsule().fill(Theme.Gradients.sunrise)
                        .frame(width: geo.size.width * CGFloat(min(done, total)) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.4), value: done)
        }
    }
}
