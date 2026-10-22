//
//  SettingsView.swift
//  RiseUp
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {

                // System / Light / Dark
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.appearances) { mode in
                        let isOn = viewModel.appearance == mode

                        Button {
                            viewModel.appearance = mode
                        } label: {
                            VStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: mode.systemImage)
                                    .font(.title3)

                                Text(mode.title)
                                    .font(.riseCaption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(
                                isOn
                                ? Theme.Colors.onAccent
                                : Theme.Colors.textPrimary
                            )
                            .background(
                                isOn
                                ? AnyShapeStyle(Theme.Gradients.brand)
                                : AnyShapeStyle(Theme.Colors.surfaceRaised),
                                in: .rect(
                                    cornerRadius: Theme.Radius.chip,
                                    style: .continuous
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }

                // Horizontally scrollable colour palettes
                Text("Colours")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.palettes) { palette in
                            paletteSwatch(palette)
                                .frame(width: 72)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("The alarm screen, wallpapers and widgets always stay dark, so the wallpapers shine.")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.appearance)
    }

    // MARK: - Palette Swatch

    private func paletteSwatch(_ palette: ColorPalette) -> some View {
        let isOn = viewModel.palette == palette

        return Button {
            viewModel.palette = palette
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: palette.accentDeep),
                                Color(hex: palette.accent),
                                Color(hex: palette.accentWarm)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .padding(4)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isOn
                                ? Theme.Colors.textPrimary
                                : .clear,
                                lineWidth: 2.5
                            )
                    }

                Text(palette.title)
                    .font(.riseCaption)
                    .foregroundStyle(
                        isOn
                        ? Theme.Colors.textPrimary
                        : Theme.Colors.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.title) colours")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {

                // Appearance
                SettingsSectionHeader(title: "Appearance")
                appearanceCard

                // Alarms
                SettingsSectionHeader(title: "Alarms")

                SettingsRow(
                    title: "Check my alarms",
                    subtitle: "Why didn't my alarm ring? Find and fix problems",
                    systemImage: "checkmark.shield.fill"
                ) {
                    viewModel.open(.alarmCheck)
                }

                GlowCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Toggle(isOn: $viewModel.guaranteesWakeUp) {
                            Label(
                                "Wake-up guarantee",
                                systemImage: "lock.shield.fill"
                            )
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .toggleStyle(.neon)

                        Text("Stop and the side or volume buttons only pause an alarm for 30 seconds. It keeps coming back until you open RiseUp and get up.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GlowCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Toggle(isOn: $viewModel.speaksTime) {
                            Label(
                                "Time Pressure",
                                systemImage: "waveform"
                            )
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .toggleStyle(.neon)

                        Text("During missions, RiseUp reads the time aloud every minute so you keep going.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // New alarms
                SettingsSectionHeader(title: "New alarms")

                SettingsRow(
                    title: "Default sound",
                    systemImage: "speaker.wave.3.fill",
                    value: viewModel.defaultSoundTitle
                ) {
                    viewModel.chooseDefaultSound()
                }

                SettingsRow(
                    title: "Wallpaper",
                    systemImage: "photo.artframe",
                    value: viewModel.defaultWallpaperTitle
                ) {
                    viewModel.chooseDefaultWallpaper()
                }

                GlowCard {
                    HStack {
                        Label(
                            "Snooze length",
                            systemImage: "zzz"
                        )
                        .font(.riseHeadline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        Picker(
                            "Snooze length",
                            selection: $viewModel.defaultSnoozeMinutes
                        ) {
                            ForEach(
                                SettingsViewModel.snoozeOptions,
                                id: \.self
                            ) { minutes in
                                Text("\(minutes) min")
                                    .tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Colors.accent)
                    }
                }

                // Help
                SettingsSectionHeader(title: "Help")

                SettingsRow(
                    title: "Questions & answers",
                    systemImage: "questionmark.bubble.fill"
                ) {
                    viewModel.open(.faq)
                }

                SettingsRow(
                    title: "Privacy",
                    subtitle: "Your data stays on this iPhone",
                    systemImage: "hand.raised.fill"
                ) {
                    viewModel.open(.privacy)
                }

                SettingsRow(
                    title: "Replay intro",
                    systemImage: "sparkles"
                ) {
                    viewModel.replayOnboarding()
                }

                // Developer tools
                #if DEBUG
                if viewModel.showsDeveloperTools {
                    SettingsSectionHeader(title: "Developer")

                    SettingsRow(
                        title: "AlarmKit Lab",
                        subtitle: "Test real alarms on this iPhone",
                        systemImage: "flask.fill"
                    ) {
                        viewModel.open(.alarmKitLab)
                    }

                    SettingsRow(
                        title: "Design Gallery",
                        subtitle: "Every RiseUp UI component",
                        systemImage: "paintpalette.fill"
                    ) {
                        viewModel.open(.designGallery)
                    }
                }
                #endif

                // App version
                VStack(spacing: Theme.Spacing.xs) {
                    AppLogo(size: AppLogo.Size.small)

                    Text("RiseUp \(viewModel.appVersion)")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    if let toast = viewModel.developerToast {
                        Text(toast)
                            .font(.riseCaption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.accent)
                            .transition(.opacity)
                            .task {
                                try? await Task.sleep(for: .seconds(2))
                                viewModel.dismissDeveloperToast()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.versionTapped()
                }
                .animation(
                    .easeInOut,
                    value: viewModel.developerToast
                )
                .padding(.top, Theme.Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .appBackground()
        .navigationTitle("Settings")
    }
}

// MARK: - Preview

#Preview {
    let dependencies = AppDependencies.preview()

    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(
                settings: dependencies.settings,
                alarmSync: dependencies.alarmSync,
                coordinator: AppCoordinator()
            )
        )
    }
}
