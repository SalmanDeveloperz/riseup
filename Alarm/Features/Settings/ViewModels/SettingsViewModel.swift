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
    var defaultWallpaperTitle: String { settings.defaultWallpaper.title }

    /// Debug builds: show the Developer tools? (App Store builds never contain them.)
    var showsDeveloperTools: Bool { settings.showsDeveloperTools }
    /// A short message after toggling Developer mode ("Developer mode on").
    private(set) var developerToast: String?
    /// Taps on the version number; 7 in a row toggles Developer mode (like Android's build number).
    @ObservationIgnored private var versionTaps = 0
    @ObservationIgnored private var lastVersionTap = Date.distantPast

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

    /// ← CALLED BY: "Alarm wallpaper" row → Wallpaper Picker (no "Default" row: this IS the default)
    /// → saved in AppSettings; every alarm without its own wallpaper uses it.
    func chooseDefaultWallpaper() {
        coordinator.presentWallpaperPicker(selected: settings.defaultWallpaper, allowsDefault: false) { [weak self] wallpaper in
            self?.settings.defaultWallpaper = wallpaper ?? .standard
        }
    }

    /// ← CALLED BY: tapping the version number in the footer.
    ///
    /// WHY hidden (Salman's request): the 🐞 menu, Developer section and "sample data" buttons
    /// made demo builds look unfinished. They now stay hidden until a developer taps the version
    /// 7 times (within a few seconds of each other). Only in Debug builds; App Store builds have
    /// no developer tools at all.
    func versionTapped(now: Date = .now) {
        #if DEBUG
        versionTaps = now.timeIntervalSince(lastVersionTap) < 1.5 ? versionTaps + 1 : 1
        lastVersionTap = now
        guard versionTaps >= 7 else { return }
        versionTaps = 0
        settings.showsDeveloperTools.toggle()
        developerToast = settings.showsDeveloperTools ? "Developer mode on" : "Developer mode off"
        #endif
    }

    func dismissDeveloperToast() { developerToast = nil }

    /// ← CALLED BY: "Replay intro". RootView notices the flag and shows onboarding again.
    func replayOnboarding() {
        settings.hasCompletedOnboarding = false
    }

    func open(_ route: SettingsRoute) {
        coordinator.show(route)               // → settingsPath.append → pushed screen
    }
}
