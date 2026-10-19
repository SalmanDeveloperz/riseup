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

    /// Navigation stack of the Morning tab. Empty = the Morning panel is showing.
    var morningPath: [MorningRoute] = []

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
    @ObservationIgnored private var onSoundPicked: ((SoundChoice) -> Void)?
    @ObservationIgnored private var onMissionPicked: ((MissionDraft) -> Void)?
    @ObservationIgnored private var onWallpaperPicked: ((WallpaperChoice) -> Void)?

    // MARK: - Alarms tab

    /// Opens the Alarm Editor. `nil` = create a new alarm.
    ///
    /// ← CALLED BY: AlarmListViewModel.addAlarmTapped() / alarmTapped(_:)
    /// → RESULT:    RootView's Alarms NavigationStack pushes ScreenFactory.makeScreen(for: .editor(...))
    func showAlarmEditor(alarmID: UUID?) {
        Trace.log(.nav, "showAlarmEditor → push the editor (\(alarmID.map(Trace.short) ?? "new alarm"))")
        selectedTab = .alarms
        alarmsPath.append(.editor(alarmID: alarmID))
    }

    /// Goes back one screen in the Alarms tab (e.g. after saving an alarm).
    func popAlarms() {
        _ = alarmsPath.popLast()
    }

    // MARK: - Morning tab

    /// Opens Records or Stats in the Morning tab.
    /// ← CALLED BY: MorningViewModel.open(_:)
    func show(_ route: MorningRoute) {
        selectedTab = .morning
        morningPath.append(route)
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
    /// `allowsCustom`: offer the user's own sounds too (the editor yes, Settings' default no).
    /// ← CALLED BY: AlarmEditorViewModel.chooseSound(), SettingsViewModel.chooseDefaultSound()
    func presentSoundPicker(selected: SoundChoice, allowsCustom: Bool = true,
                            onPick: @escaping (SoundChoice) -> Void) {
        onSoundPicked = onPick
        sheet = .soundPicker(selected: selected, allowsCustom: allowsCustom)
    }

    /// ← CALLED BY: SoundPickerViewModel.done() → delivers the result, closes the sheet.
    func completeSoundPicker(with sound: SoundChoice) {
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

    /// Opens the Wallpaper Picker. `onPick` gets the choice when the user confirms: the wallpaper
    /// (`nil` = "Default") and, after "Use wallpaper + sound", the scene's sound.
    /// ← CALLED BY: AlarmEditorViewModel.chooseWallpaper(), SettingsViewModel.chooseDefaultWallpaper()
    func presentWallpaperPicker(selected: Wallpaper?, allowsDefault: Bool, sound: SoundChoice,
                                onPick: @escaping (WallpaperChoice) -> Void) {
        onWallpaperPicked = onPick
        sheet = .wallpaperPicker(selected: selected, allowsDefault: allowsDefault, sound: sound)
    }

    /// ← CALLED BY: WallpaperPickerViewModel.done() / use(…) → delivers the result, closes the sheet.
    func completeWallpaperPicker(with choice: WallpaperChoice) {
        onWallpaperPicked?(choice)
        dismissSheet()
    }

    /// Opens Now Playing for the sleep sounds (Screen #20).
    /// ← CALLED BY: SleepViewModel.openPlayer()
    func presentSleepPlayer() {
        sheet = .sleepPlayer
    }

    /// Opens the Quick Alarm sheet, optionally preset to `minutes`.
    /// ← CALLED BY: AlarmListViewModel.quickAlarmTapped(), open(.nap) (a widget's nap button)
    func presentQuickAlarm(minutes: Int? = nil) {
        sheet = .quickAlarm(minutes: minutes)
    }

    // MARK: - Links from widgets

    /// Opens what a widget link asks for (see DeepLink).
    /// ← CALLED BY: RootView `.onOpenURL`
    /// WHY ignored during a wake-up: a widget tap must never cover the Ringing screen or a mission.
    func open(_ link: DeepLink) {
        Trace.log(.nav, "open(\(link)) ← a widget link")
        if case .ringing = fullScreen { return }
        // WHY (found in the Simulator): a sheet left open earlier stayed on top of the editor the
        // link opened. A link means "show me THIS", so whatever was open closes first.
        dismissSheet()
        switch link {
        case .newAlarm:
            showAlarmEditor(alarmID: nil)
        case .alarm(let id):
            alarmsPath.removeAll()                    // not on top of another open editor
            showAlarmEditor(alarmID: id)              // the editor shows the lock if a wake-up is pending
        case .nap(let minutes):
            selectedTab = .alarms
            presentQuickAlarm(minutes: minutes)
        }
    }

    /// Closes any sheet and forgets pending callbacks.
    /// ← CALLED BY: Cancel buttons, the complete… methods above, RootView's `onDismiss` (swipe down)
    func dismissSheet() {
        sheet = nil
        onSoundPicked = nil
        onMissionPicked = nil
        onWallpaperPicked = nil
    }

    // MARK: - Full screen

    /// Shows the ringing/mission flow for an alarm, on top of everything (even onboarding).
    ///
    /// ← CALLED BY: RootView when AlarmLaunchRouter receives "Start Mission" from the lock screen,
    ///              or when a sync finds an alarm ringing; AlarmListViewModel.resumeWakeUp
    ///
    /// WHY close a sheet first (found in code review): SwiftUI won't show a full-screen cover
    /// while a sheet (mission picker, sound picker…) is up. "Start Mission" has already silenced
    /// the system alarm, so the user would get silence and no mission. We close the sheet, wait
    /// for its slide-down animation, then show the ringing screen.
    func presentRinging(alarmID: UUID) {
        Trace.log(.nav, "presentRinging(\(Trace.short(alarmID))) → full-screen Ringing flow")
        guard sheet != nil else {
            fullScreen = .ringing(alarmID: alarmID)
            return
        }
        dismissSheet()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))   // the sheet's dismiss animation
            self?.fullScreen = .ringing(alarmID: alarmID)
        }
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
