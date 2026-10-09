//
//  MissionView.swift
//  RiseUp
//
//  LAYER: View (a "router" for missions)
//  WHAT:  Shows the right mission screen (Math / Typing / Shake) for a MissionDraft.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: RingingView (real wake-up) and MissionPickerView ("Try it" practice)
//    → BUILDS:  MathMissionView / TypingMissionView / ShakeMissionView with their ViewModels
//    → onInteraction / onComplete are passed straight through to the mission ViewModel
//
//  WHY a separate router view: both the Ringing screen and the "Try it" practice show
//  missions. Writing the `switch` once means a new mission type is added in ONE place.
//
//  IMPORTANT: give MissionView a different `.id(...)` for each mission (RingingView does).
//  WHY: two Math missions in a row would otherwise REUSE the first one's @State
//  ViewModel, and the second mission would start already solved.
//

import SwiftUI

struct MissionView: View {
    let mission: MissionDraft
    let shakeDetector: any ShakeDetecting
    let onInteraction: () -> Void
    let onComplete: () -> Void

    var body: some View {
        switch mission.type {
        case .math:
            MathMissionView(viewModel: MathMissionViewModel(
                mission: mission, onInteraction: onInteraction, onComplete: onComplete))
        case .typing:
            TypingMissionView(viewModel: TypingMissionViewModel(
                mission: mission, onInteraction: onInteraction, onComplete: onComplete))
        case .shake:
            ShakeMissionView(viewModel: ShakeMissionViewModel(
                mission: mission, detector: shakeDetector, onInteraction: onInteraction, onComplete: onComplete))
        case .memory, .steps, .squat, .photo, .barcode:
            // Phase 3 missions. The picker doesn't offer them yet; this is a safety net.
            VStack(spacing: Theme.Spacing.lg) {
                Text("\(mission.type.title) mission arrives in Phase 3.")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button("Skip", action: onComplete).buttonStyle(.ghost)
            }
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
                        .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.4), value: done)
        }
    }
}
