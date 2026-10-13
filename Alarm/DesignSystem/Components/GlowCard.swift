//
//  GlowCard.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  A rounded dark card that can "glow" with the sunrise gradient border.
//  USED BY: alarm cards, settings rows, lab sections; anything that groups content.
//

import SwiftUI

/// A container card. When `isGlowing` is true it gets a gradient border and a pink glow shadow.
///
/// LEARN: `<Content: View>` makes this a *generic* view. The card can wrap ANY content
/// (text, buttons, stacks), and Swift still knows the exact type at compile time.
struct GlowCard<Content: View>: View {
    /// Highlighted cards (for example, an enabled alarm) glow; others stay calm.
    var isGlowing: Bool = false

    /// LEARN: `@ViewBuilder` lets callers pass several views inside `{ }`, the same
    /// way `VStack { ... }` works.
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    // WHY the shadow is on the background shape only (found in the smoothness review):
                    // a shadow on the whole card made iOS trace every letter inside it too, an extra
                    // drawing pass per card that made long lists scroll less smoothly.
                    .shadow(color: isGlowing ? Theme.Colors.neonPink.opacity(0.35) : .clear, radius: 18, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    // LEARN: `AnyShapeStyle` lets one expression return either a gradient
                    // or a plain colour. Swift needs a single concrete type there.
                    .strokeBorder(
                        isGlowing ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline),
                        lineWidth: isGlowing ? 1.5 : 1
                    )
            }
            // LEARN: `.animation(_:value:)` animates the glow whenever `isGlowing` changes.
            .animation(.easeInOut(duration: 0.25), value: isGlowing)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        GlowCard(isGlowing: true) {
            Text("Glowing card").font(.riseTitle).foregroundStyle(Theme.Colors.textPrimary)
        }
        GlowCard {
            Text("Calm card").font(.riseTitle).foregroundStyle(Theme.Colors.textSecondary)
        }
    }
    .padding()
    .appBackground()
}
