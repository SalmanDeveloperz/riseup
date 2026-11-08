//
//  MathMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15a: Math)
//  WHAT:  Big problem, the typed answer, and a custom neon number pad.
//  VIEWMODEL: MathMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .math)
//
//  WHY a custom keypad instead of the iOS keyboard: it's bigger (easier half-asleep),
//  always visible, and can't be dismissed by accident.
//

import SwiftUI

struct MathMissionView: View {
    @State private var viewModel: MathMissionViewModel
    /// Drives the left-right "wrong answer" wobble.
    @State private var wobble: CGFloat = 0

    init(viewModel: MathMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            MissionProgressHeader(type: .math, done: viewModel.solved, total: viewModel.total)

            Spacer(minLength: 0)

            Text(viewModel.problem.text + " =")
                .font(.riseClock(size: 44))
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.problem)

            Text(viewModel.input.isEmpty ? "?" : viewModel.input)
                .font(.riseClock(size: 56))
                .monospacedDigit()
                .foregroundStyle(viewModel.input.isEmpty ? AnyShapeStyle(Theme.Colors.textTertiary) : AnyShapeStyle(Theme.Gradients.brand))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Gradients.brand, lineWidth: 1.5)
                }
                .offset(x: wobble)

            Spacer(minLength: 0)

            keypad
        }
        // Wrong answer → wobble + error buzz. Right answer → success tap.
        .onChange(of: viewModel.wrongAnswerCount) { playWobble() }
        .sensoryFeedback(.error, trigger: viewModel.wrongAnswerCount)
        .sensoryFeedback(.success, trigger: viewModel.rightAnswerCount)
    }

    // MARK: - Keypad

    private var keypad: some View {
        // LEARN: `Grid` lays views out in rows and columns, like a table.
        Grid(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        key(Text("\(digit)"), accessibility: "\(digit)") { viewModel.tapDigit(digit) }
                    }
                }
            }
            GridRow {
                key(Image(systemName: "delete.left.fill"), accessibility: "Delete") { viewModel.deleteDigit() }
                key(Text("0"), accessibility: "0") { viewModel.tapDigit(0) }
                key(Image(systemName: "checkmark"), isPrimary: true, accessibility: "Check answer") { viewModel.submit() }
            }
        }
    }

    private func key(_ label: some View, isPrimary: Bool = false, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.riseClock(size: 28))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(isPrimary ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.surfaceRaised))
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        // WHY required (found in the review): an empty label made VoiceOver read nothing for digits.
        .accessibilityLabel(accessibility)
    }

    /// Quick left-right shake of the answer box.
    private func playWobble() {
        let steps: [CGFloat] = [-14, 12, -8, 5, 0]
        for (i, x) in steps.enumerated() {
            withAnimation(.easeInOut(duration: 0.06).delay(Double(i) * 0.06)) { wobble = x }
        }
    }
}

/// Shrinks a little while pressed. Used by keypad keys.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MathMissionView(viewModel: MathMissionViewModel(
        mission: MissionDraft(type: .math, difficulty: .normal, repetitions: 3),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
