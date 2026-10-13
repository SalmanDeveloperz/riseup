//
//  SettingsView.swift
//  RiseUp
//
//  LAYER: View (Screen #26 Settings, the Settings tab's root)
//  WHAT:  Grouped cards: Alarms (check, Time Pressure), New alarms (sound, snooze),
//         Help (FAQ, privacy, replay intro), About, and Developer tools in Debug builds.
//  VIEWMODEL: SettingsViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: ScreenFactory.makeRoot(for: .settings)
//    → each row calls a ViewModel method → AppCoordinator → pushed screen or sheet
//  REPLACES: SettingsHomePlaceholderView (Phase 0).
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SettingsSectionHeader(title: "Alarms")
                SettingsRow(title: "Check my alarms",
                            subtitle: "Why didn't my alarm ring? Find and fix problems",
                            systemImage: "checkmark.shield.fill") {
                    viewModel.open(.alarmCheck)                      // → Screen #28
                }
                GlowCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Toggle(isOn: $viewModel.guaranteesWakeUp) {
                            Label("Wake-up guarantee", systemImage: "lock.shield.fill")
                                .font(.riseHeadline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .toggleStyle(.neon)
                        // WHY explain it: iOS lets Stop and the side/volume buttons silence an alarm, and
                        // no app can block that. Users should know why the alarm comes back.
                        Text("Stop and the side or volume buttons only pause an alarm for 30 seconds. It keeps coming back until you open RiseUp and get up.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                GlowCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Toggle(isOn: $viewModel.speaksTime) {
                            Label("Time Pressure", systemImage: "waveform")
                                .font(.riseHeadline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .toggleStyle(.neon)
                        Text("During missions, RiseUp reads the time aloud every minute so you keep going.")
                            .font(.riseCaption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                SettingsSectionHeader(title: "New alarms")
                SettingsRow(title: "Default sound", systemImage: "speaker.wave.3.fill",
                            value: viewModel.defaultSoundTitle) {
                    viewModel.chooseDefaultSound()                   // → Sound Picker sheet
                }
                // WHY short (found in the Simulator): a longer title + subtitle next to "Golden Hour"
                // wrapped into five cramped lines.
                SettingsRow(title: "Wallpaper", systemImage: "photo.artframe", value: viewModel.defaultWallpaperTitle) {
                    viewModel.chooseDefaultWallpaper()               // → Wallpaper Picker sheet
                }
                GlowCard {
                    HStack {
                        Label("Snooze length", systemImage: "zzz")
                            .font(.riseHeadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Picker("Snooze length", selection: $viewModel.defaultSnoozeMinutes) {
                            ForEach(SettingsViewModel.snoozeOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Colors.neonPink)
                    }
                }

                SettingsSectionHeader(title: "Help")
                SettingsRow(title: "Questions & answers", systemImage: "questionmark.bubble.fill") {
                    viewModel.open(.faq)
                }
                SettingsRow(title: "Privacy", subtitle: "Your data stays on this iPhone",
                            systemImage: "hand.raised.fill") {
                    viewModel.open(.privacy)
                }
                SettingsRow(title: "Replay intro", systemImage: "sparkles") {
                    viewModel.replayOnboarding()                     // → RootView shows onboarding
                }

                // WHY `#if DEBUG`: these tools exist only in builds run from Xcode.
                // They're removed automatically from the App Store build (Release configuration).
                // Even in Debug they hide until Developer mode is on (tap the version 7 times).
                #if DEBUG
                if viewModel.showsDeveloperTools {
                SettingsSectionHeader(title: "Developer")
                SettingsRow(title: "AlarmKit Lab", subtitle: "Test real alarms on this iPhone",
                            systemImage: "flask.fill") {
                    viewModel.open(.alarmKitLab)
                }
                SettingsRow(title: "Design Gallery", subtitle: "Every RiseUp UI component",
                            systemImage: "paintpalette.fill") {
                    viewModel.open(.designGallery)
                }
                }
                #endif

                VStack(spacing: Theme.Spacing.xs) {
                    AppLogo(size: AppLogo.Size.small)
                    Text("RiseUp \(viewModel.appVersion)")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    if let toast = viewModel.developerToast {
                        Text(toast)
                            .font(.riseCaption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.neonPink)
                            .transition(.opacity)
                            .task {
                                try? await Task.sleep(for: .seconds(2))
                                viewModel.dismissDeveloperToast()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.versionTapped() }          // 7 taps → Developer mode
                .animation(.easeInOut, value: viewModel.developerToast)
                .padding(.top, Theme.Spacing.lg)
            }
            .padding(Theme.Spacing.lg)
        }
        .appBackground()
        .navigationTitle("Settings")
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(settings: dependencies.settings, alarmSync: dependencies.alarmSync,
                                                  coordinator: AppCoordinator()))
    }
}
