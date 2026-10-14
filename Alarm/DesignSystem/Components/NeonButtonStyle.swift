//
//  NeonButtonStyle.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  The two button looks used across the app: `.neon` (primary) and `.ghost` (secondary).
//  USED BY: any `Button` via `.buttonStyle(.neon)` or `.buttonStyle(.ghost)`.
//
//  LEARN: A `ButtonStyle` changes how a normal SwiftUI `Button` LOOKS, while the
//  button keeps its behaviour (tap handling, accessibility, disabled state).
//  That's better than building a fake button from `Text` + `.onTapGesture`.
//

import SwiftUI

/// Filled gradient capsule with a glow. The main "do it" button on a screen.
struct NeonButtonStyle: ButtonStyle {
    /// LEARN: `@Environment(\.isEnabled)` reads whether `.disabled(true)` was applied to the button.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.riseHeadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Colors.onAccent)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(Theme.Gradients.brand, in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            .shadow(color: Theme.Colors.accent.opacity(isEnabled ? 0.45 : 0), radius: 16, y: 6)
            .opacity(isEnabled ? 1 : 0.4)
            // LEARN: `configuration.isPressed` is true while the finger is down,
            // so the button shrinks slightly while pressed. That small detail makes the UI feel alive.
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Transparent button with a thin border. For secondary actions ("Cancel", "Later").
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.riseHeadline)
            .multilineTextAlignment(.center)
            // LEARN: `configuration.role` is the role given to the Button, e.g.
            // `Button("Delete", role: .destructive)`. Destructive actions turn red automatically.
            // WHY here: a style's own `.foregroundStyle` wins over one set outside the button,
            // so the style itself must pick the danger colour.
            .foregroundStyle(configuration.role == .destructive ? Theme.Colors.danger : Theme.Colors.textPrimary)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.surfaceRaised.opacity(configuration.isPressed ? 1 : 0.6),
                        in: .rect(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Short names

// LEARN: These extensions let us write `.buttonStyle(.neon)` instead of
// `.buttonStyle(NeonButtonStyle())`. Apple's own `.bordered` works the same way.
extension ButtonStyle where Self == NeonButtonStyle {
    static var neon: NeonButtonStyle { NeonButtonStyle() }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        Button("Save alarm") {}
            .buttonStyle(.neon)
        Button("Cancel") {}
            .buttonStyle(.ghost)
        Button("Disabled") {}
            .buttonStyle(.neon)
            .disabled(true)
    }
    .padding()
    .appBackground()
}
