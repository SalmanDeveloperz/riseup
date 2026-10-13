//
//  Routes.swift
//  RiseUp
//
//  LAYER: Coordinator
//  WHAT:  Every place the app can navigate to, written as enums.
//  USED BY: AppCoordinator (stores them), ScreenFactory (turns them into screens).
//
//  LEARN: A "route" is a value that describes a screen, e.g. `.alarmKitLab` or
//  `.ringing(alarmID:)`. Navigation becomes plain data: pushing a screen just means
//  appending a route to an array. It's easy to read, test and deep-link
//  (an alarm notification can say "go to .ringing(id)").
//
//  Each phase adds new cases here.
//
//  CONNECTIONS (how this file is wired to the rest of the app):
//    ← STORED IN:   AppCoordinator (alarmsPath, settingsPath, fullScreen)
//    → TURNED INTO SCREENS BY: ScreenFactory.makeScreen(for:) — one `case` per route
//    → READ BY:     RootView's `.navigationDestination(for:)` and `.fullScreenCover(item:)`
//
//  ADDING A NEW SCREEN = 3 steps (follow the compiler errors after step 1):
//    1. add a `case` here
//    2. add the same `case` in ScreenFactory.makeScreen(for:) to build the View + ViewModel
//    3. add a method in AppCoordinator that appends/sets the route, and call it from a ViewModel
//

import Foundation

/// The four bottom tabs.
enum AppTab: String, CaseIterable, Hashable {
    case alarms
    case morning
    case sleep
    case settings

    var title: String {
        switch self {
        case .alarms: "Alarms"
        case .morning: "Morning"
        case .sleep: "Sleep"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .alarms: "alarm.fill"
        case .morning: "sun.horizon.fill"
        case .sleep: "moon.zzz.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// Screens pushed inside the Alarms tab (on top of the Alarm List).
///
/// FLOW: AlarmListViewModel.addAlarmTapped() → AppCoordinator.showAlarmEditor(alarmID: nil)
///       → alarmsPath.append(.editor(alarmID: nil)) → RootView's NavigationStack pushes
///       → ScreenFactory.makeScreen(for: .editor(...)) builds the screen.
enum AlarmsRoute: Hashable {
    /// Create (`alarmID == nil`) or edit (`alarmID` = existing WakeAlarm.id) an alarm.
    ///
    /// LEARN: `UUID?` is an *optional*: either a UUID or `nil` (nothing).
    /// We use `nil` to mean "new alarm", so one route covers both create and edit.
    case editor(alarmID: UUID?)
}

/// Screens pushed inside the Morning tab (Phase 5).
enum MorningRoute: Hashable {
    /// Month calendar of wake-ups (Screen #24).
    case records
    /// Charts: wake-up time, snoozes, mood (Screen #25).
    case stats
}

/// Screens pushed inside the Settings tab.
enum SettingsRoute: Hashable {
    /// "Why didn't my alarm ring?": checks permissions and schedules, offers fixes (Screen #28).
    case alarmCheck
    /// Questions & answers (Screen #29).
    case faq
    /// What RiseUp stores and why (Screen #29).
    case privacy
    /// Debug screen to test AlarmKit on a real iPhone (Phase 0 spike).
    case alarmKitLab
    /// Debug screen showing every Design System component.
    case designGallery
}

/// Screens that slide up from the bottom as a sheet, on top of whatever is showing.
///
/// FLOW (example, Sound Picker):
///   AlarmEditorViewModel.chooseSound() → AppCoordinator.presentSoundPicker(selected:onPick:)
///   → coordinator.sheet = .soundPicker(...) → RootView's `.sheet(item:)` shows it
///   → user taps Done → SoundPickerViewModel → coordinator.completeSoundPicker(with:)
///   → the editor's `onPick` callback receives the sound → sheet closes.
enum SheetRoute: Hashable, Identifiable {
    /// Choose an alarm sound (Screen #13). Starts with `selected` highlighted.
    case soundPicker(selected: AlarmSound)
    /// "Ring in 10 minutes" (Screen #7). `minutes`: preset from a widget's nap button (nil = the usual 10).
    case quickAlarm(minutes: Int?)
    /// Choose a mission and its settings (Screens #9 + #10). `editing` = change an existing one.
    case missionPicker(editing: MissionDraft?)
    /// Now Playing: sleep-sound volumes, sleep timer, pause/stop (Screen #20).
    case sleepPlayer
    /// Choose the wallpaper (and optionally its sound) behind the Ringing screen (Screens #32/#33).
    /// `selected == nil` = "Default". `allowsDefault`: true from the alarm editor, false when choosing
    /// Settings' default itself. `sound`: the current alarm sound (played with your own photos).
    case wallpaperPicker(selected: Wallpaper?, allowsDefault: Bool, sound: AlarmSound)

    var id: Self { self }
}

/// Screens that cover the WHOLE screen (no tab bar), shown on top of everything.
///
/// LEARN: `Identifiable` is required by SwiftUI's `.fullScreenCover(item:)`.
/// Using the route itself as its own id (`var id: Self { self }`) is a common trick.
enum FullScreenRoute: Hashable, Identifiable {
    /// The alarm is ringing → show the mission flow for this WakeAlarm.
    case ringing(alarmID: UUID)
    /// First launch: welcome → goal → permission → first alarm (Screens #1–#4).
    case onboarding

    var id: Self { self }
}
