//
//  MemoryMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15d: Memory)
//  WHAT:  A square grid of tiles. Some glow for a moment; then you tap the same ones.
//  VIEWMODEL: MemoryMissionViewModel (decides every tile's state; this file only paints it).
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .memory)
//

import SwiftUI

struct MemoryMissionView: View {
    @State private var viewModel: MemoryMissionViewModel

    init(viewModel: MemoryMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            MissionProgressHeader(type: .memory, done: viewModel.roundsDone, total: viewModel.total)

            Text(viewModel.instruction)
                .font(.riseHeadline)
                .foregroundStyle(viewModel.phase == .mistake ? Theme.Colors.danger : Theme.Colors.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: viewModel.instruction)

            Spacer(minLength: 0)

            grid

            Spacer(minLength: 0)
        }
        .onAppear { viewModel.start() }        // → first pattern
        .onDisappear { viewModel.stop() }      // → stop the round timer
        .sensoryFeedback(.error, trigger: viewModel.mistakeCount)
        .sensoryFeedback(.success, trigger: viewModel.roundsDone)
    }

    // MARK: - Grid

    private var grid: some View {
        let size = viewModel.gridSize
        // LEARN: `Grid` + `GridRow` build a table. Each tile's number is `row * size + column`
        // (see the numbering picture in MemoryPatternGenerator).
        return Grid(horizontalSpacing: Theme.Spacing.xs, verticalSpacing: Theme.Spacing.xs) {
            ForEach(0..<size, id: \.self) { row in
                GridRow {
                    ForEach(0..<size, id: \.self) { column in
                        tile(row * size + column)
                    }
                }
            }
        }
        // WHY aspectRatio(1): the grid stays square on every iPhone size.
        .aspectRatio(1, contentMode: .fit)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func tile(_ index: Int) -> some View {
        let state = viewModel.state(of: index)
        return Button {
            viewModel.tap(index)                 // → right or wrong tile
        } label: {
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .fill(fill(for: state))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(state == .missed ? Theme.Colors.accent : Theme.Colors.hairline, lineWidth: state == .missed ? 2 : 1)
                }
                .shadow(color: state == .lit ? Theme.Colors.accent.opacity(0.7) : .clear, radius: 12)
                .scaleEffect(state == .lit || state == .found ? 1.0 : 0.94)
                .aspectRatio(1, contentMode: .fit)
                .animation(.spring(duration: 0.25), value: state)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(viewModel.phase != .recall)
        .accessibilityLabel("Tile \(index + 1)")
    }

    private func fill(for state: MemoryMissionViewModel.TileState) -> AnyShapeStyle {
        switch state {
        case .dark, .missed: AnyShapeStyle(Theme.Colors.surfaceRaised)
        case .lit: AnyShapeStyle(Theme.Gradients.brand)
        case .found: AnyShapeStyle(Theme.Gradients.success)
        case .wrong: AnyShapeStyle(Theme.Colors.danger)
        }
    }
}

#Preview {
    MemoryMissionView(viewModel: MemoryMissionViewModel(
        mission: MissionDraft(type: .memory, difficulty: .normal, repetitions: 2),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
