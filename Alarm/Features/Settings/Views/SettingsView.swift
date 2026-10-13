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
                #if DEBUG
                SettingsSectionHeader(title: "Developer")
                SettingsRow(title: "AlarmKit Lab", subtitle: "Test real alarms on this iPhone",
                            systemImage: "flask.fill") {
                    viewModel.open(.alarmKitLab)
                }
                SettingsRow(title: "Design Gallery", subtitle: "Every RiseUp UI component",
                            systemImage: "paintpalette.fill") {
                    viewModel.open(.designGallery)
                }
                #endif

                VStack(spacing: Theme.Spacing.xs) {
                    AppLogo(size: AppLogo.Size.small)
                    Text("RiseUp \(viewModel.appVersion)")
                        .font(.riseCaption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
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
        SettingsView(viewModel: SettingsViewModel(settings: dependencies.settings, coordinator: AppCoordinator()))
    }
}
