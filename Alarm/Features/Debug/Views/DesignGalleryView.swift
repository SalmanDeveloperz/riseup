//
//  DesignGalleryView.swift
//  RiseUp
//
//  LAYER: View (debug tool)
//  WHAT:  Shows every Design System colour, gradient, font and component on one screen.
//  USED BY: Settings → Developer → Design Gallery.
//
//  WHY: when we tweak Theme.swift, this screen shows the effect everywhere at once.
//  TRY: change `Theme.Colors.neonPink` to another hex value and look at this screen.
//

import SwiftUI

struct DesignGalleryView: View {
    @State private var isToggleOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                section("Logo") {
                    HStack(spacing: Theme.Spacing.lg) {
                        AppLogo(isBreathing: true)
                        AppLogo(size: AppLogo.Size.small)
                    }
                }

                section("Colors") {
                    // LEARN: `LazyVGrid` lays items out in columns; `.adaptive(minimum:)`
                    // fits as many 64-pt columns as the screen width allows.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: Theme.Spacing.sm) {
                        swatch(Theme.Colors.neonPink, "Pink")
                        swatch(Theme.Colors.neonPurple, "Purple")
                        swatch(Theme.Colors.neonOrange, "Orange")
                        swatch(Theme.Colors.neonBlue, "Blue")
                        swatch(Theme.Colors.success, "Success")
                        swatch(Theme.Colors.warning, "Warning")
                        swatch(Theme.Colors.danger, "Danger")
                        swatch(Theme.Colors.surface, "Surface")
                    }
                }

                section("Gradients") {
                    HStack(spacing: Theme.Spacing.sm) {
                        gradientTile(Theme.Gradients.sunrise, "Sunrise")
                        gradientTile(Theme.Gradients.night, "Night")
                        gradientTile(Theme.Gradients.success, "Success")
                    }
                }

                section("Typography") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Large Title!").font(.riseLargeTitle)
                        Text("Title!").font(.riseTitle)
                        Text("Headline!").font(.riseHeadline)
                        Text("Body text reads like this!").font(.riseBody)
                        Text("Caption text!").font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                }

                section("Clock") {
                    BigClockText(hour: 6, minute: 30)
                }

                section("Buttons") {
                    VStack(spacing: Theme.Spacing.sm) {
                        Button("Primary (.neon)") {}.buttonStyle(.neon)
                        Button("Secondary (.ghost)") {}.buttonStyle(.ghost)
                    }
                }

                section("Cards & toggle") {
                    VStack(spacing: Theme.Spacing.sm) {
                        GlowCard(isGlowing: isToggleOn) {
                            Toggle(isOn: $isToggleOn) {
                                VStack(alignment: .leading) {
                                    BigClockText(hour: 7, minute: 15, size: 40, isActive: isToggleOn)
                                    Text("Mon – Fri").font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .toggleStyle(.neon)
                        }
                        Text("Flip the switch: the card glow follows.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Design Gallery")
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
            content()
        }
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .fill(color)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Theme.Colors.hairline))
            Text(name).font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func gradientTile(_ gradient: LinearGradient, _ name: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .fill(gradient)
                .frame(height: 64)
            Text(name).font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    NavigationStack { DesignGalleryView() }
}
