//
//  Theme.swift
//  RiseUp
//
//  LAYER: Design System (Shared: compiled into the app AND the RiseUpWidgets extension)
//  WHAT:  The single source of truth for colours, gradients, spacing and corner radii, plus the two
//         user choices that change them (#35 Themes):
//           • AppearanceMode: System / Light / Dark  → which neutral colours (backgrounds, text)
//           • ColorPalette:   Sunrise / Ocean / Aurora / Ember / Lavender → which accent colours
//  USED BY: every View in the app, the widgets and the lock screen / Dynamic Island alarm UI.
//  DATA:  reads the chosen palette from the App Group UserDefaults (so the widgets match the app).
//
//  CONNECTIONS:
//    ← WRITTEN BY: AppSettings.palette (→ Theme.palette + ThemeStorage.save)
//    ← READ BY:    every `Theme.Colors.…` / `Theme.Gradients.…` in the app and widget extension
//    → STORES IN:  WidgetShared.defaults["theme.palette"] (App Group)
//
//  WHY in /Shared: the widget extension is a separate program and can't see app files.
//  Sharing this one file keeps the widgets and lock screen in exactly the same colours.
//
//  LEARN: A "design system" means we never type raw colours or numbers like
//  `Color(red: 1, green: 0.2, blue: 0.5)` or `.padding(17)` inside screens.
//  Screens say `Theme.Colors.accent` or `Theme.Spacing.md` instead. That's exactly why adding
//  light mode and colour palettes only needed THIS file (plus a few spots that used plain white).
//

import SwiftUI
import UIKit

// MARK: - The user's choices

/// System / Light / Dark. Chosen in Settings → Appearance (AppSettings.appearance).
nonisolated enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// What we hand to `.preferredColorScheme`. `nil` = follow the iPhone's setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The accent colours. Each palette fills the same four ROLES, so screens never care which one is on.
/// LEARN: "role" names (accent, accentDeep…) instead of colour names (pink, purple…) are what let a
/// palette change the colours without lying: `accent` is pink in Sunrise and blue in Ocean.
/// WHY never rename a case: the raw value is saved (AppSettings + App Group).
nonisolated enum ColorPalette: String, CaseIterable, Identifiable, Sendable {
    case sunrise, ocean, aurora, ember, lavender

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunrise: "Sunrise"
        case .ocean: "Ocean"
        case .aurora: "Aurora"
        case .ember: "Ember"
        case .lavender: "Lavender"
        }
    }

    /// The main accent: buttons, highlights, selected things, values in Settings.
    var accent: UInt32 {
        switch self {
        case .sunrise: 0xFF3D8B   // neon pink (RiseUp's original)
        case .ocean: 0x1FA2FF
        case .aurora: 0x22D3A0
        case .ember: 0xFF5A36
        case .lavender: 0xD36BFF
        }
    }

    /// Start of the brand gradient (the deeper, cooler side).
    var accentDeep: UInt32 {
        switch self {
        case .sunrise: 0x8B5CFF
        case .ocean: 0x4B5BFF
        case .aurora: 0x0EA5A0
        case .ember: 0xD6264A
        case .lavender: 0x8B5CFF
        }
    }

    /// End of the brand gradient (the warmer, lighter side).
    var accentWarm: UInt32 {
        switch self {
        case .sunrise: 0xFF8A3D
        case .ocean: 0x2EE6C9
        case .aurora: 0xB6F23D
        case .ember: 0xFFB23D
        case .lavender: 0xFF9ED8
        }
    }

    /// A second, cool accent: night / sleep features and the background glow.
    var accentCool: UInt32 {
        switch self {
        case .sunrise: 0x3DD6FF
        case .ocean: 0x7C5CFF
        case .aurora: 0x3DA5FF
        case .ember: 0xFF7AA8
        case .lavender: 0x6FA8FF
        }
    }
}

/// Saves/loads the palette where BOTH the app and the widgets can read it (the App Group).
nonisolated enum ThemeStorage {
    static let paletteKey = "theme.palette"

    static func loadPalette() -> ColorPalette {
        let saved = WidgetShared.defaults?.string(forKey: paletteKey) ?? UserDefaults.standard.string(forKey: paletteKey)
        return saved.flatMap(ColorPalette.init(rawValue:)) ?? .sunrise
    }

    static func save(_ palette: ColorPalette) {
        WidgetShared.defaults?.set(palette.rawValue, forKey: paletteKey)
        UserDefaults.standard.set(palette.rawValue, forKey: paletteKey)   // in case the App Group isn't set up
    }
}

/// Namespace for all visual constants.
///
/// LEARN: `enum Theme` has no cases, so nobody can create a `Theme` value.
/// It's used purely as a folder ("namespace") for `static` constants.
enum Theme {

    /// The palette in use right now.
    /// WHY `nonisolated(unsafe)`: colours are read from everywhere (views, widgets), and this changes only
    /// on the main thread when the user picks a palette (AppSettings). The app then rebuilds its views
    /// (RiseUpApp `.id(palette)`), so every colour is read again.
    nonisolated(unsafe) static var palette: ColorPalette = ThemeStorage.loadPalette()

    // MARK: - Colors

    /// Every colour used by the app.
    /// LEARN: these are computed (`var … { }`) instead of constants, because they depend on two things that
    /// can change: the palette, and light/dark mode. `Color.adaptive` asks iOS "light or dark?" every time
    /// it draws, so switching Appearance needs no extra code at all.
    enum Colors {
        // Backgrounds, from the canvas to raised elements.
        static var background: Color { .adaptive(light: 0xF6F3FB, dark: 0x0B0B1A) }     // the app canvas
        static var surface: Color { .adaptive(light: 0xFFFFFF, dark: 0x16162E) }        // cards
        static var surfaceRaised: Color { .adaptive(light: 0xECE7F6, dark: 0x21214A) }  // pressed cards, inputs, chips

        // Accents (from the chosen palette; a little deeper in light mode so they stay readable on white).
        static var accent: Color { .accent(Theme.palette.accent) }
        static var accentDeep: Color { .accent(Theme.palette.accentDeep) }
        static var accentWarm: Color { .accent(Theme.palette.accentWarm) }
        static var accentCool: Color { .accent(Theme.palette.accentCool) }

        // Meaning colours (the same in every palette, so "danger" always looks like danger).
        static var success: Color { .adaptive(light: 0x12B76A, dark: 0x3DFFA2) }
        static var warning: Color { .adaptive(light: 0xD99100, dark: 0xFFC53D) }
        static var danger: Color { .adaptive(light: 0xE5354B, dark: 0xFF4D5E) }

        // Text: white on dark, deep ink on light, with the same three strengths.
        static var textPrimary: Color { .adaptive(light: 0x16142A, dark: 0xFFFFFF) }
        static var textSecondary: Color { .adaptive(light: 0x16142A, dark: 0xFFFFFF, lightOpacity: 0.62, darkOpacity: 0.65) }
        static var textTertiary: Color { .adaptive(light: 0x16142A, dark: 0xFFFFFF, lightOpacity: 0.42, darkOpacity: 0.4) }

        /// Thin borders on cards that are NOT highlighted.
        static var hairline: Color { .adaptive(light: 0x16142A, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.08) }

        /// Text/icons drawn ON an accent colour or gradient (buttons, badges): always white.
        static let onAccent = Color.white

        /// The dark canvas, in EVERY appearance: for places that must stay dark (the alarm's Live Activity).
        static let alwaysDarkBackground = Color(hex: 0x0B0B1A)
    }

    // MARK: - Gradients

    /// Signature gradients, built from the palette.
    enum Gradients {
        /// The brand gradient (deep → accent → warm). In Sunrise: purple → pink → orange, like a sunrise.
        /// Used for primary buttons, active cards and the big clock.
        static var brand: LinearGradient {
            LinearGradient(colors: [Colors.accentDeep, Colors.accent, Colors.accentWarm],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        /// Cool → deep. Used for night/sleep features.
        static var night: LinearGradient {
            LinearGradient(colors: [Colors.accentCool, Colors.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        /// Green → cool accent. Used for success states ("Mission complete!").
        static var success: LinearGradient {
            LinearGradient(colors: [Colors.success, Colors.accentCool], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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

// MARK: - Color helpers

extension Color {
    /// Creates a colour from a hex number such as `0xFF3D8B` (the format designers use).
    ///
    /// LEARN: `extension` adds new abilities to an existing type, here Apple's `Color`.
    /// LEARN: `>>` shifts bits right and `& 0xFF` keeps the last 8 bits, which pulls the
    /// red, green and blue bytes out of one number.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: opacity))
    }

    /// One colour for light mode, another for dark mode; iOS picks while drawing.
    /// LEARN: `UIColor { traits in … }` is a "dynamic colour": the closure runs every time iOS draws,
    /// with the current light/dark setting in `traits`. SwiftUI uses it like any other colour.
    /// WHY `.light` vs everything else: RiseUp's home is the dark look, so "unspecified" means dark.
    nonisolated static func adaptive(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light ? UIColor(hex: light, alpha: lightOpacity) : UIColor(hex: dark, alpha: darkOpacity)
        })
    }

    /// A palette accent: as-is on dark, a bit deeper and richer on light (so pale ones stay readable on white).
    nonisolated static func accent(_ hex: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let color = UIColor(hex: hex, alpha: 1)
            guard traits.userInterfaceStyle == .light else { return color }
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return UIColor(hue: h, saturation: min(1, s * 1.08), brightness: b * 0.84, alpha: a)
        })
    }
}

extension UIColor {
    /// `UIColor(hex: 0xFF3D8B)`, the same idea as `Color(hex:)`.
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
