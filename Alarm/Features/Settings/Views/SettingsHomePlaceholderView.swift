//
//  SettingsHomePlaceholderView.swift
//  RiseUp
//
//  LAYER: View (temporary; the real Settings screen is built in Phase 4)
//  WHAT:  Settings tab root. For now it only links to developer tools.
//  USED BY: ScreenFactory → Settings tab.
//  NAVIGATION: tapping a row calls a closure; ScreenFactory wires that closure to AppCoordinator.
//
//  LEARN: The view receives `onOpen…` closures instead of the coordinator itself.
//  The view doesn't know WHAT happens on tap, only that something should. That
//  keeps it reusable and easy to preview (the preview passes empty closures `{}`).
//

import SwiftUI

struct SettingsHomePlaceholderView: View {
    var onOpenAlarmKitLab: () -> Void
    var onOpenDesignGallery: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("The full Settings screen arrives in Phase 4!")
                    .font(.riseBody)
                    .foregroundStyle(Theme.Colors.textSecondary)

                // WHY `#if DEBUG`: these tools exist only in builds run from Xcode.
                // They're removed automatically from the App Store build (Release configuration).
                #if DEBUG
                Text("DEVELOPER")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, Theme.Spacing.md)

                row(title: "AlarmKit Lab",
                    subtitle: "Test real alarms on this iPhone",
                    systemImage: "flask.fill",
                    action: onOpenAlarmKitLab)

                row(title: "Design Gallery",
                    subtitle: "Every RiseUp UI component",
                    systemImage: "paintpalette.fill",
                    action: onOpenDesignGallery)
                #endif
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Settings")
    }

    /// One tappable row.
    ///
    /// LEARN: a private function that returns `some View` is a simple way to avoid
    /// copy-pasting the same layout. Bigger reusable pieces become their own `struct`.
    private func row(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlowCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(Theme.Gradients.sunrise)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(subtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        // LEARN: `.plain` removes the default blue button tint so our card keeps its colours.
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsHomePlaceholderView(onOpenAlarmKitLab: {}, onOpenDesignGallery: {})
    }
}
