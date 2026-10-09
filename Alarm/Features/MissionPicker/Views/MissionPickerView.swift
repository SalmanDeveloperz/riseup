//
//  MissionPickerView.swift
//  RiseUp
//
//  LAYER: View (Screens #9 + #10, shown as a sheet)
//  WHAT:  Grid of mission types → settings (difficulty, how many, example, Try it) → Add.
//  VIEWMODEL: MissionPickerViewModel (owns this sheet's own navigation path).
//
//  CONNECTIONS (the path to this screen):
//    Alarm Editor "Add mission" → AlarmEditorViewModel.addMission()
//      → AppCoordinator.presentMissionPicker → coordinator.sheet = .missionPicker(...)
//      → RootView `.sheet(item:)` → ScreenFactory.makeScreen(for: SheetRoute) → this view
//

import SwiftUI

struct MissionPickerView: View {
    @State private var viewModel: MissionPickerViewModel

    init(viewModel: MissionPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // The sheet's OWN navigation: bound to viewModel.path (not AppCoordinator).
        NavigationStack(path: $viewModel.path) {
            typeGrid
                .navigationDestination(for: MissionPickerViewModel.Step.self) { step in
                    switch step {
                    case .settings: settings
                    case .practice: practice
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Step 1: type grid

    private var typeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                GridItem(.flexible(), spacing: Theme.Spacing.sm)],
                      spacing: Theme.Spacing.sm) {
                ForEach(viewModel.types) { type in
                    typeCard(type)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Choose a mission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.cancel() }
            }
        }
    }

    private func typeCard(_ type: MissionType) -> some View {
        Button {
            viewModel.choose(type)                       // → settings step
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: type.systemImage)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(type.isAvailable ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised),
                                    in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    Spacer()
                    if !type.isAvailable {
                        Text("Phase 3")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.surfaceRaised, in: .capsule)
                    }
                }
                Text(type.title)
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(type.pitch)
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(viewModel.draft?.type == type ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline))
            }
            .opacity(type.isAvailable ? 1 : 0.5)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!type.isAvailable)
    }

    // MARK: - Step 2: settings

    @ViewBuilder
    private var settings: some View {
        if let draft = viewModel.draft {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: draft.type.systemImage)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Theme.Gradients.sunrise, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                        VStack(alignment: .leading) {
                            Text(draft.type.title).font(.riseTitle).foregroundStyle(Theme.Colors.textPrimary)
                            Text(draft.type.pitch).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }

                    if draft.type.usesDifficulty {
                        GlowCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Difficulty").font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                                difficultyChips(selected: draft.difficulty)
                            }
                        }
                    }

                    GlowCard {
                        HStack {
                            Text("How many").font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            roundButton("minus") { viewModel.adjustRepetitions(by: -1) }
                            Text("\(draft.repetitions)")
                                .font(.riseClock(size: 30))
                                .monospacedDigit()
                                .foregroundStyle(Theme.Gradients.sunrise)
                                .frame(minWidth: 60)
                                .contentTransition(.numericText())
                                .animation(.snappy, value: draft.repetitions)
                            roundButton("plus") { viewModel.adjustRepetitions(by: 1) }
                        }
                    }

                    GlowCard(isGlowing: true) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("EXAMPLE").font(.riseCaption).tracking(1).foregroundStyle(Theme.Colors.neonPink)
                            Text(viewModel.sampleText)
                                .font(.riseTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(draft.summary)
                                .font(.riseCaption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }

                    if viewModel.practiceSuccessCount > 0 {
                        Label("Nice! You're ready for tomorrow.", systemImage: "checkmark.seal.fill")
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.success)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Button {
                        viewModel.startPractice()
                    } label: {
                        Label("Try it now", systemImage: "play.fill")
                    }
                    .buttonStyle(.ghost)

                    Button(viewModel.isEditing ? "Save mission" : "Add mission") {
                        viewModel.save()                  // → AppCoordinator → editor
                    }
                    .buttonStyle(.neon)
                }
                .padding(Theme.Spacing.lg)
                .animation(.spring, value: viewModel.practiceSuccessCount)
            }
            .appBackground()
            .navigationTitle("Mission settings")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: viewModel.practiceSuccessCount)
            .sensoryFeedback(.selection, trigger: draft.difficulty)
        }
    }

    private func difficultyChips(selected: MissionDifficulty) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(MissionDifficulty.allCases) { level in
                let isOn = level == selected
                Button {
                    viewModel.setDifficulty(level)
                } label: {
                    VStack(spacing: 4) {
                        // One to five bars: a quick visual of "how hard".
                        HStack(spacing: 2) {
                            ForEach(0...level.rawValue, id: \.self) { _ in
                                Capsule().frame(width: 4, height: 10)
                            }
                        }
                        Text(level.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isOn ? .white : Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised),
                                in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.surfaceRaised, in: .circle)
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(symbol == "plus" ? "More" : "Fewer")
    }

    // MARK: - Practice

    @ViewBuilder
    private var practice: some View {
        if let draft = viewModel.draft {
            MissionView(
                mission: draft,
                shakeDetector: viewModel.shakeDetector,
                onInteraction: {},
                onComplete: { viewModel.practiceFinished() }   // → back to settings with "Nice!"
            )
            .padding(Theme.Spacing.lg)
            .appBackground()
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        MissionPickerView(viewModel: MissionPickerViewModel(
            editing: nil, shakeDetector: MockShakeDetector(), coordinator: AppCoordinator()
        ))
    }
}
