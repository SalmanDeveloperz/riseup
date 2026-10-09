//
//  SoundPickerView.swift
//  RiseUp
//
//  LAYER: View (Screen #13, shown as a sheet)
//  WHAT:  Sounds grouped by category. Tap to select + hear a preview. Done / Cancel.
//  VIEWMODEL: SoundPickerViewModel.
//
//  CONNECTIONS (the path to this screen):
//    Alarm Editor "Sound" row → AlarmEditorViewModel.chooseSound()
//      → AppCoordinator.presentSoundPicker → coordinator.sheet = .soundPicker(...)
//      → RootView `.sheet(item:)` → ScreenFactory.makeScreen(for: SheetRoute) → this view
//

import SwiftUI

struct SoundPickerView: View {
    @State private var viewModel: SoundPickerViewModel

    init(viewModel: SoundPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // LEARN: a sheet has no navigation bar of its own. Wrapping it in a
        // NavigationStack gives us a title and toolbar buttons.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Tap a sound to hear it. On the lock screen, iOS plays it even in Silent mode.")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    ForEach(viewModel.categories) { category in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(category.rawValue.uppercased())
                                .font(.riseCaption)
                                .tracking(1)
                                .foregroundStyle(Theme.Colors.textTertiary)
                            ForEach(category.sounds) { sound in
                                row(sound)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .appBackground()
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.done() }.fontWeight(.bold)
                }
            }
        }
        // Stop any preview if the sheet is swiped away.
        .onDisappear { viewModel.stopPreview() }
        .sensoryFeedback(.selection, trigger: viewModel.selected)
    }

    // MARK: - Row

    private func row(_ sound: AlarmSound) -> some View {
        let isSelected = viewModel.selected == sound
        let isPlaying = viewModel.previewing == sound

        return Button {
            viewModel.select(sound)                     // → select + preview
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: sound.systemImage)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Gradients.sunrise))
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(sound.subtitle)
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                if isPlaying {
                    // LEARN: `.symbolEffect(.variableColor.iterative)` animates the waves
                    // one by one, a cheap "now playing" indicator.
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(Theme.Colors.neonPink)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                        .accessibilityLabel("Playing")
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.neonPink)
                        .accessibilityHidden(true)
                }
            }
            .padding(Theme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline),
                                  lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SoundPickerView(viewModel: SoundPickerViewModel(
        selected: .radar,
        audio: MockAudioService(),
        coordinator: AppCoordinator()
    ))
}
