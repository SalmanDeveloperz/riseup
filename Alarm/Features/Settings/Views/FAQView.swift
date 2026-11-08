//
//  FAQView.swift
//  RiseUp
//
//  LAYER: View (Screen #29 Questions & answers)
//  WHAT:  Common questions in expandable cards. Static content, so no ViewModel is needed.
//  DATA:  none (the text lives in `FAQItem.all`).
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: .faq) ← SettingsViewModel.open(.faq)
//
//  WHY no ViewModel here: our rule is "logic lives in ViewModels". This screen has no
//  logic at all, only text, so a ViewModel would be an empty class. Rules serve clarity;
//  they don't require empty files.
//

import SwiftUI

/// One question and its answer.
nonisolated struct FAQItem: Identifiable, Sendable {
    let question: String
    let answer: String
    var id: String { question }

    /// TRY: add your own question at the end and find it in Settings → Questions & answers.
    static let all: [FAQItem] = [
        FAQItem(question: "Will my alarm ring in Silent mode, during Focus, or if I close RiseUp?",
                answer: "Yes. RiseUp uses Apple's AlarmKit, the same system the Clock app uses. iOS keeps your alarms even when the app is closed or the phone restarted."),
        FAQItem(question: "Why is there a Stop button if my alarm has a mission?",
                answer: "iOS always shows Stop on a ringing alarm and apps can't hide it. That's why RiseUp schedules backup alarms 1, 2, 3, 5 and 8 minutes later. They keep ringing until you finish the mission."),
        FAQItem(question: "What if the Photo mission doesn't recognise my spot?",
                answer: "Try a similar angle and turn on the light. After 3 failed photos you can choose to solve 5 hard maths problems instead, so you're never stuck with a ringing alarm."),
        FAQItem(question: "Why does RiseUp want my camera or Motion & Fitness?",
                answer: "Only for missions: the camera for Photo and Barcode, Motion & Fitness for Steps. If you don't allow them, those missions switch to Math."),
        FAQItem(question: "Can I snooze?",
                answer: "Alarms without missions can snooze, up to the limit you choose in the editor. Alarms with missions can't: that's the point!"),
        FAQItem(question: "What is the wake-up check?",
                answer: "If you turn it on in the editor, RiseUp rings once more a few minutes after you got up, asking “Are you up?”. Stop it (or open RiseUp) to answer."),
        FAQItem(question: "What is Time Pressure?",
                answer: "While you do a mission, RiseUp reads the time aloud every minute. You can switch it off in Settings."),
        FAQItem(question: "My alarm didn't ring. What now?",
                answer: "Open Settings → Check my alarms. It finds the usual causes (a permission switched off, an alarm missing in iOS) and fixes them with one tap."),
        FAQItem(question: "Do I need an internet connection?",
                answer: "No. Everything works offline, and your data never leaves your iPhone."),
    ]
}

struct FAQView: View {
    /// Which questions are open. LEARN: a `Set` is perfect for "which of these are on?".
    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(FAQItem.all) { item in
                    card(item)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Questions & answers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ item: FAQItem) -> some View {
        let isOpen = expanded.contains(item.id)
        return Button {
            withAnimation(.spring(duration: 0.3)) {
                if isOpen { expanded.remove(item.id) } else { expanded.insert(item.id) }
            }
        } label: {
            GlowCard(isGlowing: isOpen) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .top) {
                        Text(item.question)
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(Theme.Colors.accent)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    if isOpen {
                        Text(item.answer)
                            .font(.riseBody)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Hides the answer" : "Shows the answer")
    }
}

#Preview {
    NavigationStack { FAQView() }
}
