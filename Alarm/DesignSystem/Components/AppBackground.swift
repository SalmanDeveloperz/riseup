//
//  AppBackground.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  The dark background with soft coloured "glows" behind every screen.
//  USED BY: every full screen, through the `.appBackground()` modifier.
//

import SwiftUI

/// Dark canvas with two blurred neon glows (pink top-left, purple bottom-right).
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.Colors.background

            // LEARN: `RadialGradient` fades a colour out from a centre point.
            // Two of them at opposite corners create the "neon glow" atmosphere.
            RadialGradient(
                colors: [Theme.Colors.neonPink.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Theme.Colors.neonBlue.opacity(0.30), .clear],
//              colors: [Theme.Colors.neonPink.opacity(0.30), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 480
            )
        }
        // LEARN: `.ignoresSafeArea()` lets the background go under the notch and home bar.
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the RiseUp background behind this view.
    ///
    /// LEARN: Wrapping a modifier in a small `extension View` function gives it a
    /// readable name. Screens just write `.appBackground()`.
    func appBackground() -> some View {
        background { AppBackground() }
    }
}

#Preview {
    Text("Helloo RiseUp")
        .font(.riseLargeTitle)
        .foregroundStyle(Theme.Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
}
