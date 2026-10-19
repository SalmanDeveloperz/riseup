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

            TextField("Start typing…", text: typedBinding, axis: .vertical)
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
                // WHY a new field per phrase (bug found on Salman's iPhone 16): the old field kept showing
                // the finished phrase, and the next letter was added to it. A new `.id` makes SwiftUI build a
                // fresh, empty field for every phrase; `typedBinding` ignores the old field's last write.
                // LEARN: `.id(value)` tells SwiftUI "this is a different view when the value changes".
                .id(viewModel.index)

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
        // The fresh field (see `.id` above) gets the keyboard straight away, so typing just continues.
        // WHY a short wait (found in the Simulator): setting focus in the same instant the old field
        // disappeared was undone by its removal; 50 ms later the new field is on screen and keeps it.
        // LEARN: `.task(id:)` runs again every time the id changes (here: each new phrase).
        .task(id: viewModel.index) {
            guard viewModel.index > 0 else { return }   // the first phrase: see the `.task` above
            try? await Task.sleep(for: .milliseconds(50))
            isFocused = true
        }
    }

    /// The text field's connection to the ViewModel. Each write says which phrase it was typed for,
    /// so a late write from the previous phrase's field can't put old text into the new one.
    ///
    /// LEARN: `Binding(get:set:)` builds a two-way connection by hand. `[phrase = viewModel.index]`
    /// captures the phrase number at the moment this field is created.
    private var typedBinding: Binding<String> {
        Binding(
            get: { viewModel.typed },
            set: { [phrase = viewModel.index] text in viewModel.type(text, forPhrase: phrase) }   // → ViewModel
        )
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
