//
//  SettingsViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #26 Settings)
//  WHAT:  The Settings tab: Time Pressure on/off, defaults for new alarms (sound, snooze),
//         links to the alarm check, FAQ, privacy, replaying the intro, and (Debug) dev tools.
//  DATA:  reads/writes AppSettings (UserDefaults). No SwiftData.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeRoot(for: .settings)
//    → READS/WRITES: AppSettings
//    → NAVIGATES:    AppCoordinator.show(.alarmCheck / .faq / .privacy / .alarmKitLab / .designGallery)
//    → SHEETS:       AppCoordinator.presentSoundPicker (default sound comes back via callback)
//

import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private let settings: AppSettings
    private let coordinator: AppCoordinator

    init(settings: AppSettings, coordinator: AppCoordinator) {
        self.settings = settings
        self.coordinator = coordinator
    }

    // MARK: - Values the View binds to

    // LEARN: get/set computed properties let the View write `$viewModel.speaksTime` while
    // the value really lives in AppSettings (and is saved there immediately).

    /// "Time Pressure": speak the time every minute during missions.
    var speaksTime: Bool {
        get { settings.speaksTimeWhileRinging }
        set { settings.speaksTimeWhileRinging = newValue }
    }

    var defaultSnoozeMinutes: Int {
        get { settings.defaultSnoozeMinutes }
        set { settings.defaultSnoozeMinutes = newValue }
    }

    var defaultSoundTitle: String { settings.defaultSound.title }

    static let snoozeOptions = AlarmEditorViewModel.snoozeMinuteOptions

    /// "1.0 (1)": version and build number from the app's Info.plist.
    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    /// ← CALLED BY: "Default sound" row → Sound Picker sheet → result saved in AppSettings
    func chooseDefaultSound() {
        coordinator.presentSoundPicker(selected: settings.defaultSound) { [weak self] sound in
            self?.settings.defaultSound = sound
        }
    }

    /// ← CALLED BY: "Replay intro". RootView notices the flag and shows onboarding again.
    func replayOnboarding() {
        settings.hasCompletedOnboarding = false
    }

    func open(_ route: SettingsRoute) {
        coordinator.show(route)               // → settingsPath.append → pushed screen
    }
}
