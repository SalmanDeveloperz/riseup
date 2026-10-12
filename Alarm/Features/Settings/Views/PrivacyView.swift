//
//  PrivacyView.swift
//  RiseUp
//
//  LAYER: View (Screen #29 Privacy)
//  WHAT:  A plain-language summary of what RiseUp stores and why. Static content.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: .privacy) ← SettingsViewModel.open(.privacy)
//
//  NOTE for the App Store (Phase 7): Apple also needs a privacy policy at a public URL and
//  the "App Privacy" answers in App Store Connect. This screen is the in-app summary; keep
//  them saying the same thing.
//

import SwiftUI

struct PrivacyView: View {
    private struct Point: Identifiable {
        let systemImage: String
        let title: String
        let text: String
        var id: String { title }
    }

    private let points: [Point] = [
        Point(systemImage: "iphone", title: "Everything stays on your iPhone",
              text: "Your alarms, missions and wake-up history are saved only on this device. RiseUp has no account and no server."),
        Point(systemImage: "camera.fill", title: "Photos",
              text: "For the Photo mission, RiseUp keeps a small picture of your spot and a numeric fingerprint of it. Morning photos are compared and then thrown away, never saved."),
        Point(systemImage: "figure.walk", title: "Motion",
              text: "Steps and movement are counted only while a mission is on screen, and never stored."),
        Point(systemImage: "chart.bar.xaxis", title: "No tracking",
              text: "No ads, no analytics, no third-party code that watches what you do."),
        Point(systemImage: "trash.fill", title: "Delete anytime",
              text: "Deleting an alarm deletes its missions and photo. Deleting the app deletes everything."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(points) { point in
                    GlowCard {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: point.systemImage)
                                .font(.title3)
                                .foregroundStyle(Theme.Gradients.sunrise)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(point.title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                                Text(point.text).font(.riseBody).foregroundStyle(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
