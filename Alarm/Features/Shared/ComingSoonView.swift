//
//  ComingSoonView.swift
//  RiseUp
//
//  LAYER: View (temporary placeholder)
//  WHAT:  A good-looking "this tab arrives in Phase N" screen.
//  USED BY: ScreenFactory for tabs that aren't built yet. Each one gets replaced by
//           its real screen in a later phase.
//  DATA:  none.
//
//  LEARN: This view has no ViewModel because it has no logic or data: it only
//  displays the values it's given. MVVM rule of thumb: add a ViewModel when a screen
//  loads data, makes decisions or navigates.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let phase: Int
    let message: String
    var showsLiveClock: Bool = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            if showsLiveClock {
                // LEARN: `TimelineView(.everyMinute)` re-draws its content at the start of
                // every minute. That's perfect for a clock and cheaper than a 1-second timer.
                TimelineView(.everyMinute) { context in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                    BigClockText(hour: parts.hour ?? 0, minute: parts.minute ?? 0, size: 88)
                }
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Theme.Gradients.sunrise)
                    // LEARN: `.symbolEffect(.pulse)` animates SF Symbols for free.
                    .symbolEffect(.pulse)
            }

            GlowCard(isGlowing: true) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Coming in Phase \(phase)")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.neonPink)
                    Text(message)
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .navigationTitle(title)
    }
}

#Preview {
    NavigationStack {
        ComingSoonView(
            title: "Alarms",
            systemImage: "alarm.fill",
            phase: 1,
            message: "Your alarm list with glowing cards lives here.",
            showsLiveClock: true
        )
    }
}
