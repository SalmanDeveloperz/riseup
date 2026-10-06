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
//  Each phase adds new cases here. Phase 1 adds `AlarmsRoute.editor(...)` etc.
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

/// Screens pushed inside the Settings tab.
enum SettingsRoute: Hashable {
    /// Debug screen to test AlarmKit on a real iPhone (Phase 0 spike).
    case alarmKitLab
    /// Debug screen showing every Design System component.
    case designGallery
}

/// Screens that cover the WHOLE screen (no tab bar), shown on top of everything.
///
/// LEARN: `Identifiable` is required by SwiftUI's `.fullScreenCover(item:)`.
/// Using the route itself as its own id (`var id: Self { self }`) is a common trick.
enum FullScreenRoute: Hashable, Identifiable {
    /// The alarm is ringing → show the mission flow for this WakeAlarm.
    case ringing(alarmID: UUID)

    var id: Self { self }
}
