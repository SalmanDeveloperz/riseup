//
//  AppCoordinator.swift
//  RiseUp
//
//  LAYER: Coordinator
//  WHAT:  The single object that decides which screen is visible.
//  USED BY: RootView (reads/binds its state), ViewModels/ScreenFactory (call its methods).
//
//  LEARN: Coordinator pattern
//  ──────────────────────────
//  Screens should not know about each other. The Alarm List shouldn't need to
//  know how to build the Alarm Editor. A screen just says "the user wants to edit
//  this alarm" and the coordinator decides what that means (push? sheet? full screen?).
//  All navigation state lives in one place:
//     selectedTab       → which tab is open
//     alarmsPath        → the stack of screens pushed in the Alarms tab
//     settingsPath      → the stack of screens pushed in the Settings tab
//     fullScreen        → a screen covering everything (e.g. ringing alarm)
//
//  CONNECTIONS:
//    ← CREATED BY:  RiseUpApp (`@State private var coordinator = AppCoordinator()`), ONE instance for the app
//    ← SHARED VIA:  `.environment(coordinator)` in RiseUpApp → read in RootView with `@Environment`
//    ← CALLED BY:   ViewModels (they receive it in their init from ScreenFactory),
//                   ScreenFactory closures (simple screens), RootView (alarm launch requests)
//    → OBSERVED BY: RootView. Its TabView, NavigationStacks and fullScreenCover are BOUND
//                   to the properties below, so changing a property = the screen changes.
//

import Foundation
import Observation

/// Owns all navigation state.
///
/// LEARN: `@Observable` makes SwiftUI watch this class. When a property changes
/// (e.g. `fullScreen = .ringing(...)`), every view that READ that property re-draws.
@Observable
final class AppCoordinator {
    var selectedTab: AppTab = .alarms

    /// Navigation stack of the Alarms tab. Empty = the Alarm List is showing.
    /// → bound in RootView: `NavigationStack(path: $coordinator.alarmsPath)`
    var alarmsPath: [AlarmsRoute] = []

    /// Navigation stack of the Settings tab. Empty = root screen.
    /// LEARN: a typed array (`[SettingsRoute]`) instead of `NavigationPath`, so you can
    /// print it and see exactly which screens are open.
    var settingsPath: [SettingsRoute] = []

    /// Screen covering the whole app, or `nil` when none.
    var fullScreen: FullScreenRoute?

    // MARK: - Alarms tab

    /// Opens the Alarm Editor. `nil` = create a new alarm.
    ///
    /// ← CALLED BY: AlarmListViewModel.addAlarmTapped() / alarmTapped(_:)
    /// → RESULT:    RootView's Alarms NavigationStack pushes ScreenFactory.makeScreen(for: .editor(...))
    func showAlarmEditor(alarmID: UUID?) {
        selectedTab = .alarms
        alarmsPath.append(.editor(alarmID: alarmID))
    }

    /// Goes back one screen in the Alarms tab (e.g. after saving an alarm).
    func popAlarms() {
        _ = alarmsPath.popLast()
    }

    // MARK: - Settings tab

    /// Opens a Settings sub-screen (switches tab if needed).
    ///
    /// ← CALLED BY: closures created in ScreenFactory.makeRoot(for: .settings)
    func show(_ route: SettingsRoute) {
        selectedTab = .settings
        settingsPath.append(route)
    }

    /// Goes back one screen in the Settings tab.
    func popSettings() {
        _ = settingsPath.popLast()
    }

    // MARK: - Full screen

    /// Shows the ringing/mission flow for an alarm, on top of everything.
    ///
    /// ← CALLED BY: RootView when AlarmLaunchRouter receives "Start Mission" from the lock screen
    func presentRinging(alarmID: UUID) {
        fullScreen = .ringing(alarmID: alarmID)
    }

    /// ← CALLED BY: RingingPlaceholderViewModel when the mission ends or the user closes it
    func dismissFullScreen() {
        fullScreen = nil
    }
}
