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
//     sheet             → a sheet sliding up from the bottom (sound picker, quick alarm…)
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

    /// Sheet sliding up from the bottom, or `nil` when none.
    /// → bound in RootView: `.sheet(item: $coordinator.sheet)`
    var sheet: SheetRoute?

    /// Screen covering the whole app, or `nil` when none.
    var fullScreen: FullScreenRoute?

    // MARK: - Sheet results (callbacks)

    // LEARN: a picker must hand its RESULT back to whoever opened it (the editor).
    // Routes are plain values and can't carry functions, so the coordinator keeps the
    // "call me back with the answer" closure until the sheet finishes.
    // `@ObservationIgnored`: no view displays these, so SwiftUI needn't watch them.
    @ObservationIgnored private var onSoundPicked: ((AlarmSound) -> Void)?
    @ObservationIgnored private var onMissionPicked: ((MissionDraft) -> Void)?

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

    // MARK: - Sheets

    /// Opens the Sound Picker. `onPick` runs with the chosen sound when the user taps Done.
    /// ← CALLED BY: AlarmEditorViewModel.chooseSound()
    func presentSoundPicker(selected: AlarmSound, onPick: @escaping (AlarmSound) -> Void) {
        onSoundPicked = onPick
        sheet = .soundPicker(selected: selected)
    }

    /// ← CALLED BY: SoundPickerViewModel.done() → delivers the result, closes the sheet.
    func completeSoundPicker(with sound: AlarmSound) {
        onSoundPicked?(sound)
        dismissSheet()
    }

    /// Opens the Mission Picker. `editing` = an existing mission to change, `nil` = add a new one.
    /// ← CALLED BY: AlarmEditorViewModel.addMission() / editMission(_:)
    func presentMissionPicker(editing: MissionDraft?, onPick: @escaping (MissionDraft) -> Void) {
        onMissionPicked = onPick
        sheet = .missionPicker(editing: editing)
    }

    /// ← CALLED BY: MissionPickerViewModel.save() → delivers the result, closes the sheet.
    func completeMissionPicker(with mission: MissionDraft) {
        onMissionPicked?(mission)
        dismissSheet()
    }

    /// Opens the Quick Alarm sheet.
    /// ← CALLED BY: AlarmListViewModel.quickAlarmTapped()
    func presentQuickAlarm() {
        sheet = .quickAlarm
    }

    /// Closes any sheet and forgets pending callbacks.
    /// ← CALLED BY: Cancel buttons, the complete… methods above, RootView's `onDismiss` (swipe down)
    func dismissSheet() {
        sheet = nil
        onSoundPicked = nil
        onMissionPicked = nil
    }

    // MARK: - Full screen

    /// Shows the ringing/mission flow for an alarm, on top of everything.
    ///
    /// ← CALLED BY: RootView when AlarmLaunchRouter receives "Start Mission" from the lock screen
    func presentRinging(alarmID: UUID) {
        fullScreen = .ringing(alarmID: alarmID)
    }

    /// Shows onboarding on top of everything (first launch, or "Replay intro" in Settings).
    ///
    /// ← CALLED BY: RootView (when AppSettings.hasCompletedOnboarding is false)
    /// WHY never over a ringing alarm: waking up always wins. Onboarding comes back next launch.
    func presentOnboarding() {
        guard fullScreen == nil else { return }
        fullScreen = .onboarding
    }

    /// ← CALLED BY: RingingViewModel (mission done / closed), OnboardingViewModel (finished)
    func dismissFullScreen() {
        fullScreen = nil
    }
}
