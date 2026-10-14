//
//  TypingMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15b: Typing)
//  WHAT:  The phrase (turning green as you type it correctly) and a text field.
//  VIEWMODEL: TypingMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .typing)
//

import SwiftUI

struct TypingMissionView: View {
    @State private var viewModel: TypingMissionViewModel
    @FocusState private var isFocused: Bool

    init(viewModel: TypingMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            MissionProgressHeader(type: .typing, done: viewModel.solvedCount, total: viewModel.total)

            Text("Type this phrase:")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textSecondary)

            highlightedPhrase
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .animation(.easeOut(duration: 0.15), value: viewModel.correctCount)

            TextField("Start typing…", text: $viewModel.typed, axis: .vertical)
                .font(.riseBody)
                .foregroundStyle(Theme.Colors.textPrimary)
                // WHY: autocorrect would "fix" words behind the user's back and break matching.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surfaceRaised, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Gradients.brand, lineWidth: 1)
                }

            Spacer(minLength: 0)
        }
        // Open the keyboard right away; the user shouldn't have to tap first.
        // WHY the short wait (found in the review): asking for the keyboard DURING the slide-in
        // animation sometimes didn't stick. 0.35 s later the screen is settled.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
        .sensoryFeedback(.success, trigger: viewModel.solvedCount)
    }

    /// The phrase with the correctly-typed part in green and the rest dimmed.
    ///
    /// LEARN: putting `Text` values inside `Text("\(a)\(b)")` joins them into ONE text
    /// with mixed styles (iOS 26's replacement for the older `textA + textB`).
    private var highlightedPhrase: Text {
        let phrase = Array(viewModel.phrase)
        let n = min(viewModel.correctCount, phrase.count)
        let done = Text(String(phrase[..<n])).foregroundStyle(Theme.Colors.success)
        let rest = Text(String(phrase[n...])).foregroundStyle(Theme.Colors.textTertiary)
        return Text("\(done)\(rest)")
    }
}

#Preview {
    TypingMissionView(viewModel: TypingMissionViewModel(
        mission: MissionDraft(type: .typing, difficulty: .easy, repetitions: 2),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
