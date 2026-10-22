//
//  SoundPickerView.swift
//  RiseUp
//
//  LAYER: View (Screen #13, shown as a sheet; + #37: search and the user's own sounds)
//  WHAT:  A search bar, "My sounds" (add from Files or a video in Photos, rename, delete),
//         then our sounds grouped by category. Tap to select + hear a preview. Done / Cancel.
//  VIEWMODEL: SoundPickerViewModel.
//
//  CONNECTIONS (the path to this screen):
//    Alarm Editor "Sound" row → AlarmEditorViewModel.chooseSound()
//      → AppCoordinator.presentSoundPicker → coordinator.sheet = .soundPicker(...)
//      → RootView `.sheet(item:)` → ScreenFactory.makeScreen(for: SheetRoute) → this view
//    "Add your own sound" → .fileImporter (Files app) / .photosPicker (videos)
//      → SoundPickerViewModel.addFile / addVideo → CustomSoundLibrary.add → SoundClipMaker
//

import PhotosUI
import SwiftUI

struct SoundPickerView: View {
    @State private var viewModel: SoundPickerViewModel

    init(viewModel: SoundPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // LEARN: a sheet has no navigation bar of its own. Wrapping it in a
        // NavigationStack gives us a title, toolbar buttons and a place for the search bar.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if viewModel.hasNoResults {
                        // LEARN: Apple's ready-made "No Results for '…'" screen.
                        ContentUnavailableView.search(text: viewModel.searchText)
                    } else {
                        if !viewModel.isSearching {
                            Text("Tap a sound to hear it. On the lock screen, iOS plays it even in Silent mode.")
                                .font(.riseCaption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        if viewModel.allowsCustom { mySoundsSection }
                        ForEach(viewModel.visibleCategories, id: \.category) { group in
                            section(group.category.rawValue) {
                                ForEach(group.sounds) { sound in row(.builtIn(sound)) }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.immediately)
            .appBackground()
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
            // LEARN: `.searchable` adds the standard iOS search bar under the title. `.always` keeps
            // it visible (it doesn't hide while scrolling), so people find it right away.
            .searchable(text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search sounds")
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
        // MARK: The two ways in (#37)
        // LEARN: `.fileImporter` shows the Files app's picker. No permission is needed: the user
        // chooses exactly one file, and iOS lends us only that file.
        .fileImporter(isPresented: $viewModel.isShowingFileImporter,
                      allowedContentTypes: SoundPickerViewModel.importableTypes) { result in
            Task { await viewModel.addFile(result) }                 // → convert + save in the background
        }
        // WHY `preferredItemEncoding: .current`: without it, Photos may first CONVERT the video to
        // another format (seconds of waiting). We only want its sound, so the original is fastest.
        .photosPicker(isPresented: $viewModel.isShowingPhotoPicker, selection: $viewModel.pickedVideo,
                      matching: .videos, preferredItemEncoding: .current)
        .onChange(of: viewModel.pickedVideo) { _, item in
            guard let item else { return }
            Task { await viewModel.addVideo(item) }
        }
        .alert("Couldn't use this sound", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Rename sound", isPresented: Binding(
            get: { viewModel.renaming != nil },
            set: { if !$0 { viewModel.renaming = nil } }
        )) {
            TextField("Name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { viewModel.confirmRename() }
        }
        .confirmationDialog("Delete “\(viewModel.deleting?.name ?? "")”?", isPresented: Binding(
            get: { viewModel.deleting != nil },
            set: { if !$0 { viewModel.deleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Sound", role: .destructive) { viewModel.confirmDelete() }
        }
    }

    // MARK: - My sounds (#37)

    @ViewBuilder
    private var mySoundsSection: some View {
        let sounds = viewModel.visibleCustomSounds
        if !viewModel.isSearching || !sounds.isEmpty {
            section("My sounds") {
                if !viewModel.isSearching { addRow }
                ForEach(sounds) { sound in row(.custom(sound)) }
            }
        }
    }

    /// "Add your own sound": a menu with the two sources, or a spinner while one is being added.
    private var addRow: some View {
        Menu {
            Button("From Files", systemImage: "folder") { viewModel.chooseFromFiles() }
            Button("Sound of a Video", systemImage: "video") { viewModel.chooseFromPhotos() }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Group {
                    if viewModel.isImporting {
                        ProgressView().tint(Theme.Colors.onAccent)
                    } else {
                        Image(systemName: "plus").font(.title3.weight(.semibold))
                    }
                }
                .foregroundStyle(Theme.Colors.onAccent)
                .frame(width: 44, height: 44)
                .background(Theme.Gradients.brand, in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isImporting ? "Adding your sound…" : "Add your own sound")
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("A song or recording from Files, or the sound of a video")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isImporting)
        .accessibilityHint("Choose a sound file or a video to use as an alarm sound")
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(.riseCaption)
                .tracking(1)
                .foregroundStyle(Theme.Colors.textTertiary)
            content()
        }
    }

    private func row(_ sound: SoundChoice) -> some View {
        let isSelected = viewModel.isSelected(sound)
        let isPlaying = viewModel.isPreviewing(sound)

        return HStack(spacing: Theme.Spacing.md) {
            Button {
                viewModel.select(sound)                     // → select + preview
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: sound.systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? AnyShapeStyle(Theme.Colors.onAccent) : AnyShapeStyle(Theme.Gradients.brand))
                        .frame(width: 44, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                                .fill(isSelected ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.surfaceRaised))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sound.title)
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(sound.subtitle)
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if isPlaying {
                        // LEARN: `.symbolEffect(.variableColor.iterative)` animates the waves
                        // one by one, a cheap "now playing" indicator.
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(Theme.Colors.accent)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                            .accessibilityLabel("Playing")
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.accent)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if case .custom(let custom) = sound {
                // WHY a visible "…" button (not only a long press): people don't guess that a
                // long press hides Rename and Delete.
                Menu {
                    customSoundActions(custom)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More for \(custom.name)")
            }
        }
        .padding(Theme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.hairline),
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .contextMenu {
            if case .custom(let custom) = sound { customSoundActions(custom) }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func customSoundActions(_ sound: CustomSound) -> some View {
        Button("Rename", systemImage: "pencil") { viewModel.startRename(sound) }
        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askToDelete(sound) }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    SoundPickerView(viewModel: SoundPickerViewModel(
        selected: .builtIn(.radar),
        audio: MockAudioService(),
        customSounds: MockCustomSoundLibrary(sounds: [
            CustomSound(id: UUID(), name: "Morning song", duration: 30, createdAt: .now),
        ]),
        alarmRepository: dependencies.alarmRepository,
        coordinator: AppCoordinator()
    ))
}
