//
//  SuccessView.swift
//  RiseUp
//
//  LAYER: View (Screen #16)
//  WHAT:  "You're up!" celebration: confetti, the wake-up time, mission time, snoozes,
//         and a "Start my day" button.
//  DATA:  shows a RingingViewModel.WakeSummary (a value), already saved as a WakeRecord.
//
//  CONNECTIONS:
//    ← SHOWN BY: RingingView when viewModel.phase == .success
//    → onClose:  RingingViewModel.close() → AppCoordinator.dismissFullScreen()
//

import SwiftUI

struct SuccessView: View {
    let summary: RingingViewModel.WakeSummary
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundStyle(Theme.Gradients.sunrise)
                    .symbolEffect(.bounce, value: appeared)
                    .shadow(color: Theme.Colors.neonOrange.opacity(0.6), radius: 30)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("You're up!")
                        .font(.riseLargeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Woke up at \(summary.wokeAt.formatted(date: .omitted, time: .shortened))")
                        .font(.riseBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if summary.missionsCompleted > 0 {
                        statTile(value: Self.durationText(summary.missionSeconds), label: "mission time", icon: "bolt.fill")
                        statTile(value: "\(summary.missionsCompleted)", label: summary.missionsCompleted == 1 ? "mission" : "missions", icon: "checkmark.seal.fill")
                    }
                    statTile(value: "\(summary.snoozeCount)", label: summary.snoozeCount == 1 ? "snooze" : "snoozes", icon: "zzz")
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Label("Start my day", systemImage: "arrow.right")
                }
                .buttonStyle(.neon)
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            ConfettiView()
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Gradients.sunrise)
            Text(value)
                .font(.riseTitle)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// 42 → "0:42", 125 → "2:05"
    static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    SuccessView(summary: .init(wokeAt: .now, missionSeconds: 42, missionsCompleted: 2, snoozeCount: 0), onClose: {})
        .padding()
        .appBackground()
}
