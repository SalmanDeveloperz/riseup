//
//  AppLogo.swift
//  RiseUp
//
//  LAYER: Design System (reusable component)
//  WHAT:  The RiseUp logo (the same picture as the app icon) with the iPhone icon's rounded
//         shape and a soft sunrise glow (the Crowing Rooster, v3). Optionally "breathes" (the glow slowly pulses).
//  DATA:  the `AppLogo` image in Assets.xcassets (made by Tools/generate_app_icon.swift).
//
//  CONNECTIONS:
//    ← USED BY: OnboardingView (welcome page, big + breathing), SettingsView (footer, small),
//               DesignGalleryView
//    → READS:   Assets.xcassets/AppLogo.imageset
//
//  WHY an image and not SF Symbols: the logo must look exactly like the icon on the Home Screen,
//  so people recognise "this is the app I tapped". Both come from the same script.
//

import SwiftUI

struct AppLogo: View {
    /// Width and height in points. Use the presets below so every screen uses the same sizes.
    var size: CGFloat = Size.hero
    /// Slowly pulsing glow (for the welcome page).
    var isBreathing = false

    /// Logo sizes used in the app. TRY: make `hero` bigger and look at the welcome page.
    enum Size {
        static let hero: CGFloat = 132
        static let small: CGFloat = 56
    }

    @State private var isGlowing = false
    /// The iPhone's "Reduce Motion" setting: the logo stays still when it's on.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            // LEARN: iPhone icons are "squircles": `.continuous` corners at about 22.5 % of the
            // width match the Home Screen shape closely.
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
            }
            .shadow(color: Theme.Colors.neonPink.opacity(isGlowing ? 0.55 : 0.25),
                    radius: isGlowing ? size * 0.3 : size * 0.14, y: size * 0.04)
            .scaleEffect(isGlowing ? 1.03 : 1)
            .onAppear {
                guard isBreathing, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { isGlowing = true }
            }
            .accessibilityLabel("RiseUp logo")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.xl) {
        AppLogo(isBreathing: true)
        AppLogo(size: AppLogo.Size.small)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .appBackground()
}
