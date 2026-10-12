//
//  SettingsRow.swift
//  RiseUp
//
//  LAYER: Design System (component)
//  WHAT:  One tappable card row: gradient icon, title, subtitle, optional value, chevron.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← USED BY: SettingsView, AlarmHealthCheckView
//
//  LEARN: this started life as a private `row(...)` function inside the Settings placeholder.
//  Once a second screen needed the same look, it became its own reusable `struct` here.
//  That's the usual path: copy-paste once is fine, the second time make a component.
//

import SwiftUI

struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    /// Small text on the right, e.g. "Radar" or "5 min".
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlowCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Theme.Gradients.sunrise, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        if let subtitle {
                            Text(subtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.xs)
                    if let value {
                        Text(value).font(.riseBody).foregroundStyle(Theme.Colors.neonPink)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        // LEARN: `.plain` removes the default blue button tint so our card keeps its colours.
        .buttonStyle(.plain)
    }
}

/// A small grey section title ("ALARMS", "HELP").
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.riseCaption)
            .tracking(1)
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.top, Theme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading) {
        SettingsSectionHeader(title: "Alarms")
        SettingsRow(title: "Check my alarms", subtitle: "Why didn't my alarm ring?", systemImage: "checkmark.shield.fill", action: {})
        SettingsRow(title: "Default sound", systemImage: "speaker.wave.3.fill", value: "Radar", action: {})
    }
    .padding()
    .appBackground()
}
