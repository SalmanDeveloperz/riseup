//
//  AppSettings.swift
//  RiseUp
//
//  LAYER: Service (app preferences, saved in UserDefaults)
//  WHAT:  Small settings that aren't alarms: onboarding finished?, speak the time during
//         missions?, default sound and snooze for new alarms, the wake-up goal from onboarding,
//         bedtime reminder (on/off + time) and the last sleep-sound mix (Phase 6), the default
//         alarm wallpaper, the hidden Developer mode switch, the Wake-up guarantee, and the look
//         (appearance: System/Light/Dark + colour palette, #35).
//  DATA:  UserDefaults (a tiny key-value store iOS keeps for every app). NOT SwiftData.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (one shared instance; tests pass their own UserDefaults)
//    ← READ BY:    RootView (show onboarding?), RingingViewModel (Time Pressure),
//                  AlarmKitScheduler (Wake-up guarantee: which alarms get a re-ring chain),
//                  AlarmEditorViewModel (defaults for new alarms), SettingsViewModel, OnboardingViewModel
//    ← WRITTEN BY: SettingsViewModel, OnboardingViewModel
//
//  LEARN: SwiftData vs UserDefaults
//  ────────────────────────────────
//  SwiftData is a real database: many rows, relationships, queries (alarms, history).
//  UserDefaults is a dictionary saved to disk: perfect for a handful of switches like these.
//  `@Observable` + `didSet` = every change is shown on screen AND saved immediately.
//

import Foundation
import Observation

/// Why the user wants to wake up (asked in onboarding). Used to suggest a first mission.
nonisolated enum WakeGoal: String, CaseIterable, Identifiable, Sendable {
    case stopSnoozing
    case beOnTime
    case morningRoutine
    case exercise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stopSnoozing: "Stop hitting snooze"
        case .beOnTime: "Never be late again"
        case .morningRoutine: "Build a morning routine"
        case .exercise: "Move first thing"
        }
    }

    var systemImage: String {
        switch self {
        case .stopSnoozing: "zzz"
        case .beOnTime: "clock.badge.checkmark.fill"
        case .morningRoutine: "sun.horizon.fill"
        case .exercise: "figure.run"
        }
    }

    /// The mission we suggest for this goal on the "first alarm" onboarding page.
    /// WHY never Photo/Barcode here: those need a registration (photo or scan) first,
    /// which is too much for a first-launch screen. Users find them in the Mission Picker.
    var suggestedMission: MissionType {
        switch self {
        case .stopSnoozing: .math
        case .beOnTime: .memory
        case .morningRoutine: .typing
        case .exercise: .squat
        }
    }
}

@Observable
final class AppSettings {
    /// LEARN: keys are plain strings. Keeping them in one place avoids typos like "hasCompleteOnboarding".
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let speaksTimeWhileRinging = "speaksTimeWhileRinging"
        static let defaultSound = "defaultSound"
        static let defaultSnoozeMinutes = "defaultSnoozeMinutes"
        static let wakeGoal = "wakeGoal"
        static let bedtimeReminderOn = "bedtimeReminderOn"
        static let bedtimeMinuteOfDay = "bedtimeMinuteOfDay"
        static let lastSleepMix = "lastSleepMix"
        static let defaultWallpaper = "defaultWallpaper"
        static let showsDeveloperTools = "showsDeveloperTools"
        static let savedWallpapers = "savedWallpapers"
        static let guaranteesWakeUp = "guaranteesWakeUp"
        static let appearance = "appearance"
    }

    @ObservationIgnored private let store: UserDefaults

    /// False until the user finishes (or skips) onboarding. → RootView shows onboarding while false.
    var hasCompletedOnboarding: Bool {
        didSet { store.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// "Time Pressure": read the time aloud every minute during missions.
    var speaksTimeWhileRinging: Bool {
        didSet { store.set(speaksTimeWhileRinging, forKey: Key.speaksTimeWhileRinging) }
    }

    /// The sound new alarms start with. TRY: change the fallback below to `.siren`.
    var defaultSound: AlarmSound {
        didSet { store.set(defaultSound.rawValue, forKey: Key.defaultSound) }
    }

    /// The snooze length new alarms start with (minutes).
    var defaultSnoozeMinutes: Int {
        didSet { store.set(defaultSnoozeMinutes, forKey: Key.defaultSnoozeMinutes) }
    }

    /// The onboarding answer, if given.
    var wakeGoal: WakeGoal? {
        didSet { store.set(wakeGoal?.rawValue, forKey: Key.wakeGoal) }
    }

    /// Phase 6: daily "time to wind down" notification on/off.
    var bedtimeReminderOn: Bool {
        didSet { store.set(bedtimeReminderOn, forKey: Key.bedtimeReminderOn) }
    }

    /// Phase 6: bedtime as minutes after midnight (22:30 → 1350). TRY: change the 1350 default below.
    var bedtimeMinuteOfDay: Int {
        didSet { store.set(bedtimeMinuteOfDay, forKey: Key.bedtimeMinuteOfDay) }
    }

    /// Phase 6: the last sleep-sound mix ("sleep_rain" → 0.7), for "Play last mix".
    /// LEARN: UserDefaults can store simple dictionaries like [String: Double] directly.
    var lastSleepMix: [String: Double] {
        didSet { store.set(lastSleepMix, forKey: Key.lastSleepMix) }
    }

    /// The wallpaper behind the Ringing screen for alarms that don't choose their own.
    /// TRY: change the fallback `Wallpaper.standard` in the init to `.surprise`.
    var defaultWallpaper: Wallpaper {
        didSet { store.set(defaultWallpaper.rawValue, forKey: Key.defaultWallpaper) }
    }

    /// Debug builds only: shows the 🐞 menu, Developer section and "sample data" buttons.
    /// Off by default, so the app looks like the real thing in demos. Turned on by tapping the
    /// version number in Settings 7 times. (App Store builds don't contain these tools at all.)
    var showsDeveloperTools: Bool {
        didSet { store.set(showsDeveloperTools, forKey: Key.showsDeveloperTools) }
    }

    /// Bookmarked wallpapers (♥ in the scene player), newest first, as `Wallpaper.rawValue`.
    var savedWallpapers: [String] {
        didSet { store.set(savedWallpapers, forKey: Key.savedWallpapers) }
    }

    /// "Wake-up guarantee": EVERY alarm (not only mission alarms) rings again 30 s after it's
    /// silenced from the lock screen, until the user gets up inside RiseUp.
    /// WHY on by default: iOS lets the side and volume buttons silence any app's alarm, and no app
    /// can block that. Ringing again is the only way to keep a sleepy press from ending the alarm.
    /// → AlarmKitScheduler.isGuarded · changed in Settings (which re-schedules every alarm).
    var guaranteesWakeUp: Bool {
        didSet { store.set(guaranteesWakeUp, forKey: Key.guaranteesWakeUp) }
    }

    /// Settings → Appearance: System / Light / Dark (#35). Dark by default: RiseUp's signature neon look.
    /// → RiseUpApp `.preferredColorScheme(appearance.colorScheme)`
    var appearance: AppearanceMode {
        didSet { store.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Settings → Appearance: the colour palette (#35). Also saved in the App Group so the widgets match.
    /// → Theme.palette (read by every colour) · RiseUpApp `.id(palette)` redraws every screen.
    var palette: ColorPalette {
        didSet {
            Theme.palette = palette
            ThemeStorage.save(palette)
        }
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        // LEARN: `object(forKey:) as? Bool ?? true` = "the saved value, or `true` if never saved".
        // (`bool(forKey:)` would return `false` for "never saved", which isn't the default we want.)
        hasCompletedOnboarding = store.bool(forKey: Key.hasCompletedOnboarding)
        speaksTimeWhileRinging = store.object(forKey: Key.speaksTimeWhileRinging) as? Bool ?? true
        defaultSound = AlarmSound(rawValue: store.string(forKey: Key.defaultSound) ?? "") ?? .radar
        defaultSnoozeMinutes = store.object(forKey: Key.defaultSnoozeMinutes) as? Int ?? 5
        wakeGoal = store.string(forKey: Key.wakeGoal).flatMap(WakeGoal.init(rawValue:))
        bedtimeReminderOn = store.bool(forKey: Key.bedtimeReminderOn)
        bedtimeMinuteOfDay = store.object(forKey: Key.bedtimeMinuteOfDay) as? Int ?? 22 * 60 + 30
        lastSleepMix = store.dictionary(forKey: Key.lastSleepMix) as? [String: Double] ?? [:]
        defaultWallpaper = store.string(forKey: Key.defaultWallpaper).flatMap(Wallpaper.init(rawValue:)) ?? .standard
        showsDeveloperTools = store.bool(forKey: Key.showsDeveloperTools)
        savedWallpapers = store.stringArray(forKey: Key.savedWallpapers) ?? []
        guaranteesWakeUp = store.object(forKey: Key.guaranteesWakeUp) as? Bool ?? true
        appearance = store.string(forKey: Key.appearance).flatMap(AppearanceMode.init(rawValue:)) ?? .dark
        palette = Theme.palette                                    // loaded by ThemeStorage at launch
    }
}
