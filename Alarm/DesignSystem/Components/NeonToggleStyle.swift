//
//  NeonToggleStyle.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  An on/off switch with a gradient track, used to enable/disable alarms.
//  USED BY: alarm cards (Phase 1), settings switches, via `.toggleStyle(.neon)`.
//

import SwiftUI

/// Custom switch: grey when off, sunrise gradient + glow when on.
struct NeonToggleStyle: ToggleStyle {
    /// LEARN: `.labelsHidden()` on a Toggle sets this environment value. Apple's own
    /// switch reads it automatically, but a custom style must check it itself.
    /// ← SET BY: AlarmCardView (`.labelsHidden()`), where only the switch should show.
    @Environment(\.labelsVisibility) private var labelsVisibility

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if labelsVisibility != .hidden {
                configuration.label
                Spacer(minLength: Theme.Spacing.sm)
            }

            // The switch itself, drawn by hand: a capsule track with a circle knob.
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Theme.Gradients.sunrise)
                                             : AnyShapeStyle(Theme.Colors.surfaceRaised))
                    .frame(width: 56, height: 32)
                    .shadow(color: configuration.isOn ? Theme.Colors.neonPink.opacity(0.5) : .clear, radius: 8)

                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .shadow(radius: 2)
            }
            // LEARN: `.animation(_:value:)` animates whenever `isOn` changes, no matter WHO
            // changed it. WHY not `withAnimation` in the tap: on the Alarm List the new
            // value arrives a moment later from the ViewModel (async), outside that
            // animation, and the knob would jump instead of sliding.
            .animation(.spring(duration: 0.25), value: configuration.isOn)
            // LEARN: `.sensoryFeedback` plays a light haptic "tick" whenever the value
            // changes. It's SwiftUI's modern replacement for UIImpactFeedbackGenerator.
            .sensoryFeedback(.selection, trigger: configuration.isOn)
        }
        // WHY the tap is on the WHOLE row (found in the smoothness review): before, only the
        // small capsule reacted, so tapping the words "Snooze" did nothing. Like Apple's
        // switches, the label is tappable too, and the row is at least 44 pt tall.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            // LEARN: `configuration.isOn` is a Binding. Toggling it updates
            // whatever state the screen gave to `Toggle(isOn:)`.
            configuration.isOn.toggle()
        }
        // WHY: the custom drawing hides Apple's built-in switch, so we tell VoiceOver
        // this behaves like a toggle and what its state is. Accessibility matters for App Store quality.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

extension ToggleStyle where Self == NeonToggleStyle {
    static var neon: NeonToggleStyle { NeonToggleStyle() }
}

#Preview {
    // LEARN: `@Previewable @State` lets a #Preview keep its own changing state.
    @Previewable @State var isOn = true
    Toggle("Alarm enabled", isOn: $isOn)
        .toggleStyle(.neon)
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding()
        .appBackground()
}
