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
//     settingsPath      → the stack of screens pushed in the Settings tab
//     fullScreen        → a screen covering everything (e.g. ringing alarm)
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

    /// Navigation stack of the Settings tab. Empty = root screen.
    /// LEARN: a typed array (`[SettingsRoute]`) instead of `NavigationPath`, so you can
    /// print it and see exactly which screens are open.
    var settingsPath: [SettingsRoute] = []

    /// Screen covering the whole app, or `nil` when none.
    var fullScreen: FullScreenRoute?

    // MARK: - Tabs & stacks

    /// Opens a Settings sub-screen (switches tab if needed).
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
    func presentRinging(alarmID: UUID) {
        fullScreen = .ringing(alarmID: alarmID)
    }

    func dismissFullScreen() {
        fullScreen = nil
    }
}
