//
//  ScreenFactory.swift
//  RiseUp
//
//  LAYER: Coordinator
//  WHAT:  Turns a route (e.g. `.alarmKitLab`) into a real screen, creating its
//         ViewModel with the right dependencies.
//  USED BY: RootView.
//
//  LEARN: This is the ONE file that knows how every screen is built. To find out
//  "what does screen X need?", look here. When we add a screen in a later phase we:
//    1. add a case to Routes.swift
//    2. add a `case` here that builds its View + ViewModel
//    3. call `coordinator.something()` from another ViewModel to navigate to it
//
//  CONNECTIONS:
//    ← CREATED BY: RootView.body (a new, cheap factory value on every redraw)
//    ← GETS ITS TOOLS FROM: AppDependencies (repository, scheduler) + AppCoordinator,
//                           both read from the SwiftUI environment in RootView
//    → BUILDS: every screen + its ViewModel, handing each ViewModel only the tools it needs
//
//  WHY a new ViewModel is created on every RootView redraw but the screen keeps the first one:
//  each screen stores its ViewModel in `@State`, and `@State` keeps its FIRST value for
//  the screen's whole life. Extra ViewModels built later are simply thrown away. They're
//  cheap because their `init` only stores references and does no loading.
//

import SwiftUI

struct ScreenFactory {
    let dependencies: AppDependencies
    let coordinator: AppCoordinator

    // MARK: - Tab roots

    /// The first screen of each tab.
    ///
    /// LEARN: `@ViewBuilder` lets a function return DIFFERENT view types from
    /// different `switch` branches. SwiftUI wraps them into one type for us.
    @ViewBuilder
    func makeRoot(for tab: AppTab) -> some View {
        switch tab {
        case .alarms:
            // Screen #6, Alarm List. Its ViewModel gets:
            //   repository  → to read/save/delete WakeAlarms
            //   scheduler   → to turn system alarms on/off, check the wake-up lock
            //   sync        → to bring database and iOS into agreement when the list appears
            //   coordinator → to open the editor, quick alarm, ringing screen
            AlarmListView(viewModel: AlarmListViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                sync: dependencies.alarmSync,
                coordinator: coordinator
            ))
        case .morning:
            // Screen #23, Morning panel. Reads wake-up history + the next alarm.
            MorningView(viewModel: MorningViewModel(
                records: dependencies.wakeRecordRepository,
                alarms: dependencies.alarmRepository,
                coordinator: coordinator
            ))
        case .sleep:
            // Screen #19, Sleep sounds. Its ViewModel gets:
            //   player      → the long-lived mixer (music survives leaving this screen)
            //   settings    → last mix + bedtime reminder switch/time
            //   reminder    → schedules the daily "wind down" notification
            //   coordinator → to open the Now Playing sheet (#20)
            SleepView(viewModel: SleepViewModel(
                player: dependencies.sleepSounds,
                settings: dependencies.settings,
                reminder: dependencies.bedtimeReminder,
                coordinator: coordinator
            ))
        case .settings:
            // Screen #26. Its ViewModel gets:
            //   settings    → Time Pressure, defaults for new alarms (UserDefaults)
            //   coordinator → to push the alarm check / FAQ / privacy and open the sound picker
            SettingsView(viewModel: SettingsViewModel(
                settings: dependencies.settings,
                alarmSync: dependencies.alarmSync,                       // re-schedules after the guarantee changes
                coordinator: coordinator
            ))
        }
    }

    // MARK: - Pushed screens

    /// Screens pushed in the Alarms tab.
    /// ← CALLED BY: RootView's `.navigationDestination(for: AlarmsRoute.self)`
    @ViewBuilder
    func makeScreen(for route: AlarmsRoute) -> some View {
        switch route {
        case .editor(let alarmID):
            // Screen #8, Alarm Editor. `alarmID == nil` → create mode, otherwise edit mode.
            // Its ViewModel gets:
            //   repository  → to load the alarm into a draft and save it back
            //   scheduler   → to ask permission and schedule/cancel with iOS
            //   coordinator → to pop back to the list after Save/Cancel/Delete
            AlarmEditorView(viewModel: AlarmEditorViewModel(
                alarmID: alarmID,
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                settings: dependencies.settings,          // defaults for NEW alarms
                wallpaperStore: dependencies.wallpaperStore,  // photo for the Wallpaper row's preview
                coordinator: coordinator
            ))
        }
    }

    /// Screens pushed in the Morning tab (Phase 5).
    /// ← CALLED BY: RootView's `.navigationDestination(for: MorningRoute.self)`
    @ViewBuilder
    func makeScreen(for route: MorningRoute) -> some View {
        switch route {
        case .records:
            RecordsView(viewModel: RecordsViewModel(records: dependencies.wakeRecordRepository))   // #24
        case .stats:
            StatsView(viewModel: StatsViewModel(records: dependencies.wakeRecordRepository))       // #25
        }
    }

    /// Screens pushed in the Settings tab.
    /// ← CALLED BY: RootView's `.navigationDestination(for: SettingsRoute.self)`
    @ViewBuilder
    func makeScreen(for route: SettingsRoute) -> some View {
        switch route {
        case .alarmCheck:
            // Screen #28 "Why didn't my alarm ring?". Reads the database AND iOS, so it gets both.
            AlarmHealthCheckView(viewModel: AlarmHealthCheckViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                sync: dependencies.alarmSync,
                stepCounter: dependencies.missionServices.steps,
                coordinator: coordinator
            ))
        case .faq:
            FAQView()                              // static text, no ViewModel needed
        case .privacy:
            PrivacyView()
        case .alarmKitLab:
            AlarmLabView(viewModel: AlarmLabViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler
            ))
        case .designGallery:
            DesignGalleryView()
        }
    }

    // MARK: - Sheets

    /// Sheets that slide up from the bottom.
    /// ← CALLED BY: RootView's `.sheet(item: $coordinator.sheet)`
    @ViewBuilder
    func makeScreen(for route: SheetRoute) -> some View {
        switch route {
        case .soundPicker(let selected):
            // Screen #13. The result goes back through coordinator.completeSoundPicker.
            SoundPickerView(viewModel: SoundPickerViewModel(
                selected: selected,
                audio: dependencies.audio,
                coordinator: coordinator
            ))
        case .quickAlarm(let minutes):
            // Screen #7. `minutes` comes from a widget's nap button (nil = the usual 10).
            QuickAlarmView(viewModel: QuickAlarmViewModel(
                minutes: minutes,
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                coordinator: coordinator
            ))
        case .missionPicker(let editing):
            // Screens #9 + #10. The result goes back through coordinator.completeMissionPicker.
            MissionPickerView(viewModel: MissionPickerViewModel(
                editing: editing,
                services: dependencies.missionServices,   // sensors for "Try it", Vision for photo registration
                coordinator: coordinator
            ))
        case .wallpaperPicker(let selected, let allowsDefault, let sound):
            // Screens #32 + #33. The result goes back through coordinator.completeWallpaperPicker.
            WallpaperPickerView(viewModel: WallpaperPickerViewModel(
                selected: selected,
                allowsDefault: allowsDefault,
                defaultWallpaper: dependencies.settings.defaultWallpaper,   // what "Default" means
                currentSound: sound,                                       // plays with your own photos
                store: dependencies.wallpaperStore,                        // the user's own photos
                audio: dependencies.audio,                                 // the scene's sound
                settings: dependencies.settings,                           // ♥ Saved scenes
                coordinator: coordinator
            ))
        case .sleepPlayer:
            // Screen #20, Now Playing. Same player service as the Sleep tab, so both stay in sync.
            SleepPlayerView(viewModel: SleepPlayerViewModel(
                player: dependencies.sleepSounds,
                settings: dependencies.settings,
                coordinator: coordinator
            ))
        }
    }

    // MARK: - Full-screen covers

    @ViewBuilder
    func makeScreen(for route: FullScreenRoute) -> some View {
        switch route {
        case .ringing(let alarmID):
            // Screens #14–#16: ringing → missions → success.
            RingingView(viewModel: RingingViewModel(
                alarmID: alarmID,
                repository: dependencies.alarmRepository,
                records: dependencies.wakeRecordRepository,
                scheduler: dependencies.alarmScheduler,
                audio: dependencies.audio,
                timeAnnouncer: dependencies.timeAnnouncer,
                sleepSounds: dependencies.sleepSounds,   // the alarm stops last night's sleep sounds
                settings: dependencies.settings,
                wallpaperStore: dependencies.wallpaperStore,
                missionServices: dependencies.missionServices,
                coordinator: coordinator
            ))
        case .onboarding:
            // Screens #1–#4. Creates the first alarm, so it needs repository + scheduler.
            OnboardingView(viewModel: OnboardingViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                settings: dependencies.settings,
                coordinator: coordinator
            ))
        }
    }
}
