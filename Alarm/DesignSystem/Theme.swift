//
//  Theme.swift
//  RiseUp
//
//  LAYER: Design System
//  WHAT:  The single source of truth for colours, gradients, spacing and corner radii.
//  USED BY: every View in the app.
//  DATA:  none (pure constants).
//
//  LEARN: A "design system" means we never type raw colours or numbers like
//  `Color(red: 1, green: 0.2, blue: 0.5)` or `.padding(17)` inside screens.
//  Screens say `Theme.Colors.neonPink` or `Theme.Spacing.md` instead.
//  If we want to change the whole app's look later, we change ONE file.
//

import SwiftUI

/// Namespace for all visual constants.
///
/// LEARN: `enum Theme` has no cases, so nobody can create a `Theme` value.
/// It's used purely as a folder ("namespace") for `static` constants.
enum Theme {

    // MARK: - Colors

    /// Every colour used by the app. Dark background + bright "neon" accents.
    enum Colors {
        // Backgrounds, from darkest to lightest.
        static let background = Color(hex: 0x0B0B1A)    // near-black navy: the app canvas
        static let surface = Color(hex: 0x16162E)       // cards
        static let surfaceRaised = Color(hex: 0x21214A) // pressed cards, inputs, chips

        // Neon accents.
        static let neonPink = Color(hex: 0xFF3D8B)
        static let neonPurple = Color(hex: 0x8B5CFF)
        static let neonOrange = Color(hex: 0xFF8A3D)
        static let neonBlue = Color(hex: 0x3DD6FF)

        // Meaning colours.
        static let success = Color(hex: 0x3DFFA2)
        static let warning = Color(hex: 0xFFC53D)
        static let danger = Color(hex: 0xFF4D5E)

        // Text. White with different opacity keeps everything readable on dark backgrounds.
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let textTertiary = Color.white.opacity(0.4)

        /// Thin borders on cards that are NOT highlighted.
        static let hairline = Color.white.opacity(0.08)
    }

    // MARK: - Gradients

    /// Signature gradients. "sunrise" is the RiseUp brand gradient.
    enum Gradients {
        /// Purple → pink → orange, like a sunrise. Used for primary buttons, active cards and the big clock.
        static let sunrise = LinearGradient(
            colors: [Colors.neonPurple, Colors.neonPink, Colors.neonOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Blue → purple. Used for night/sleep features.
        static let night = LinearGradient(
            colors: [Colors.neonBlue, Colors.neonPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Green → blue. Used for success states ("Mission complete!").
        static let success = LinearGradient(
            colors: [Colors.success, Colors.neonBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Spacing

    /// Spacing scale based on multiples of 4 points.
    ///
    /// WHY: a fixed scale makes every screen feel consistent. Designers call this a "4-pt grid".
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40
    }

    // MARK: - Corner radius

    enum Radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 24
        static let button: CGFloat = 20
    }
}

// MARK: - Color + hex

extension Color {
    /// Creates a colour from a hex number such as `0xFF3D8B` (the format designers use).
    ///
    /// LEARN: `extension` adds new abilities to an existing type, here Apple's `Color`.
    /// LEARN: `>>` shifts bits right and `& 0xFF` keeps the last 8 bits, which pulls the
    /// red, green and blue bytes out of one number.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
