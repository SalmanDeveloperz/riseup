//
//  WallpaperPickerView.swift
//  RiseUp
//
//  LAYER: View (Screen #32 Wallpaper Picker)
//  WHAT:  "Default" + "Surprise me" rows · category tabs (♥ Saved, Around the World…) · a grid of LIVE
//         animated cards, each showing its sound · My Photos (add, long-press to delete).
//         Tap a card → the full-screen Scene Player (#33): wallpaper + sound together.
//  VIEWMODEL: WallpaperPickerViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeScreen(for: SheetRoute.wallpaperPicker)
//    → card tap → viewModel.openPlayer → ScenePlayerView (full screen, sound plays)
//    → Done / Use → viewModel → AppCoordinator.completeWallpaperPicker
//
//  WHY the grid shows one category at a time: every card is a live animation. A few at once is
//  smooth; all 14 at once would make older iPhones work hard for no reason.
//

import PhotosUI
import SwiftUI

struct WallpaperPickerView: View {
    @State private var viewModel: WallpaperPickerViewModel
    /// The picture chosen in the system photo picker (loaded into Data, then handed to the ViewModel).
    @State private var pickedItem: PhotosPickerItem?
    @State private var isPickingPhoto = false

    init(viewModel: WallpaperPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                           GridItem(.flexible(), spacing: Theme.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Every scene has its own sound. Tap one to play it full screen. Wallpapers come alive when the alarm rings, more and more until you're up.")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if viewModel.allowsDefault {
                        quickRow(title: viewModel.defaultTitle, subtitle: "Change it in Settings → Alarm wallpaper",
                                 wallpaper: viewModel.defaultWallpaper, choice: nil)
                    }
                    quickRow(title: "Surprise me", subtitle: "A different wallpaper every morning",
                             wallpaper: .surprise, choice: .surprise)
                    categoryTabs
                    grid
                }
                .padding(Theme.Spacing.lg)
            }
            .appBackground()
            .navigationTitle("Wallpaper")
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
        .task { await viewModel.loadPhotos() }
        // WHY the modifier (not a PhotosPicker button): the button's label closure can run off the
        // main thread in Swift 6 and couldn't read our screen state without warnings.
        .photosPicker(isPresented: $isPickingPhoto, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) {
            guard let item = pickedItem else { return }
            Task {
                // LEARN: `loadTransferable` gets the picture's bytes from the Photos library.
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.addPhoto(data)                  // → WallpaperStore (background)
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingPlayer) {
            ScenePlayerView(viewModel: viewModel)          // the same ViewModel: playlist, bookmarks, choice
        }
        .onDisappear { viewModel.stopSound() }             // never leave a scene's sound playing
        .alert("Wallpaper", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sensoryFeedback(.selection, trigger: viewModel.selection)
        .sensoryFeedback(.selection, trigger: viewModel.category)
    }

    // MARK: - Default / Surprise rows

    private func quickRow(title: String, subtitle: String, wallpaper: Wallpaper, choice: Wallpaper?) -> some View {
        let isOn = viewModel.isSelected(choice)
        return Button {
            viewModel.choose(choice)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                WallpaperView(wallpaper: wallpaper, photo: viewModel.photo(for: wallpaper), isThumbnail: true)
                    .frame(width: 46, height: 72)
                    .clipShape(.rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    .overlay {
                        if choice == .surprise {
                            Image(systemName: "dice.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Gradients.sunrise)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline), lineWidth: isOn ? 2 : 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(viewModel.categories) { category in
                    let isOn = viewModel.category == category
                    Button {
                        withAnimation(.spring(duration: 0.3)) { viewModel.category = category }
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.riseCaption.weight(.semibold))
                            .foregroundStyle(isOn ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .frame(minHeight: 40)
                            .background(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.surfaceRaised), in: .capsule)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            if viewModel.category == .myPhotos {
                addPhotoCard
            }
            ForEach(viewModel.wallpapersInCategory) { wallpaper in
                card(wallpaper, title: wallpaper.title)
                    .contextMenu {
                        if case .photo(let id) = wallpaper {
                            Button("Delete photo", systemImage: "trash", role: .destructive) {
                                viewModel.deletePhoto(id)
                            }
                        }
                    }
            }
        }
        .id(viewModel.category)                       // fresh grid per tab (with a fade)
        .transition(.opacity)
        if viewModel.category == .myPhotos && viewModel.photoIDs.isEmpty {
            Text("Add a photo that makes you smile: your family, your goal, your dream trip. Long-press a photo to delete it.")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        if viewModel.category == .saved && viewModel.wallpapersInCategory.isEmpty {
            Label("Tap ♥ in the player to save the scenes you love. They'll wait for you here.", systemImage: "heart")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    private func card(_ wallpaper: Wallpaper, title: String) -> some View {
        let isOn = viewModel.isSelected(wallpaper)
        return Button {
            viewModel.openPlayer(wallpaper)               // → Scene Player: wallpaper + its sound
        } label: {
            WallpaperView(wallpaper: wallpaper, photo: viewModel.photo(for: wallpaper),
                          energy: .fixed(0.35), isThumbnail: true)
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    Text(title)
                        .font(.riseHeadline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                        .padding(Theme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                }
                .overlay(alignment: .topLeading) {
                    if viewModel.hasSignatureSound(wallpaper) {
                        Label(viewModel.sound(for: wallpaper).title, systemImage: "music.note")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: .capsule)
                            .padding(Theme.Spacing.xs)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Theme.Colors.neonPink)
                            .padding(Theme.Spacing.xs)
                    }
                }
                .clipShape(.rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(isOn ? AnyShapeStyle(Theme.Gradients.sunrise) : AnyShapeStyle(Theme.Colors.hairline), lineWidth: isOn ? 3 : 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(title) wallpaper")
        .accessibilityHint("Plays the scene full screen with its sound")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var addPhotoCard: some View {
        Button {
            isPickingPhoto = true                         // → system photo library
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                if viewModel.isAddingPhoto {
                    ProgressView().tint(Theme.Colors.textPrimary)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.Gradients.sunrise)
                }
                Text("Add your photo")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(9 / 16, contentMode: .fit)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Colors.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(viewModel.isAddingPhoto)
        .accessibilityLabel("Add your own photo as a wallpaper")
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        WallpaperPickerView(viewModel: WallpaperPickerViewModel(
            selected: .live(.aurora), allowsDefault: true, defaultWallpaper: .standard, currentSound: .radar,
            store: MockWallpaperStore(), audio: MockAudioService(),
            settings: AppSettings(store: UserDefaults(suiteName: "preview")!), coordinator: AppCoordinator()
        ))
    }
}
