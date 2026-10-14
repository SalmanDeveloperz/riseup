//
//  SuccessView.swift
//  RiseUp
//
//  LAYER: View (Screen #16)
//  WHAT:  "You're up!" celebration: confetti, the wake-up time, mission time, snoozes,
//         a "How do you feel?" mood check-in (#17), and a "Start my day" button.
//  DATA:  shows a RingingViewModel.WakeSummary (a value), already saved as a WakeRecord.
//
//  CONNECTIONS:
//    ← SHOWN BY: RingingView when viewModel.phase == .success
//    → onMood:   RingingViewModel.setMood → WakeRecordRepository (Morning tab, Stats)
//    → onClose:  RingingViewModel.close() → AppCoordinator.dismissFullScreen()
//

import SwiftUI

struct SuccessView: View {
    let summary: RingingViewModel.WakeSummary
    /// The mood chosen so far (nil = none yet).
    var mood: Mood? = nil
    var onMood: (Mood) -> Void = { _ in }
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundStyle(Theme.Gradients.brand)
                    .symbolEffect(.bounce, value: appeared)
                    .shadow(color: Theme.Colors.accentWarm.opacity(0.6), radius: 30)

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

                if summary.wakeUpCheckMinutes > 0 {
                    // Wake-Up Check (#18): tell the user what will happen, so it's not a surprise.
                    Label("Wake-up check in \(summary.wakeUpCheckMinutes) min. Don't go back to bed!", systemImage: "eye.fill")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.surface, in: .capsule)
                }

                moodPicker

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

    /// "How do you feel?" with five big emoji buttons. Optional: "Start my day" works without it.
    private var moodPicker: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(mood.map { "Feeling \($0.title.lowercased()). Noted!" } ?? "How do you feel?")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .contentTransition(.opacity)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Mood.allCases) { option in
                    Button {
                        onMood(option)
                    } label: {
                        Text(option.emoji)
                            .font(.system(size: 34))
                            .frame(width: 54, height: 54)
                            .background(mood == option ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.surface),
                                        in: .circle)
                            .scaleEffect(mood == option ? 1.12 : (mood == nil ? 1 : 0.9))
                            .opacity(mood == nil || mood == option ? 1 : 0.5)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
            }
            .animation(.spring(duration: 0.3), value: mood)
        }
        .sensoryFeedback(.selection, trigger: mood)
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Gradients.brand)
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
    SuccessView(summary: .init(wokeAt: .now, missionSeconds: 42, missionsCompleted: 2, snoozeCount: 0, wakeUpCheckMinutes: 5),
                mood: .good, onClose: {})
        .padding()
        .appBackground()
}
