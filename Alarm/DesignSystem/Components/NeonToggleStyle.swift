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
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: Theme.Spacing.sm)

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
            .onTapGesture {
                // LEARN: `configuration.isOn` is a Binding. Toggling it updates
                // whatever state the screen gave to `Toggle(isOn:)`.
                withAnimation(.spring(duration: 0.25)) {
                    configuration.isOn.toggle()
                }
            }
            // LEARN: `.sensoryFeedback` plays a light haptic "tick" whenever the value
            // changes. It's SwiftUI's modern replacement for UIImpactFeedbackGenerator.
            .sensoryFeedback(.selection, trigger: configuration.isOn)
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
