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
            //   scheduler   → to turn system alarms on/off
            //   coordinator → to open the editor
            AlarmListView(viewModel: AlarmListViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                coordinator: coordinator
            ))
        case .morning:
            ComingSoonView(
                title: "Morning",
                systemImage: AppTab.morning.systemImage,
                phase: 5,
                message: "Weather, quote of the day, wake-up streaks and records."
            )
        case .sleep:
            ComingSoonView(
                title: "Sleep",
                systemImage: AppTab.sleep.systemImage,
                phase: 6,
                message: "Relaxing sleep sounds with a timer, and later sleep tracking."
            )
        case .settings:
            SettingsHomePlaceholderView(
                onOpenAlarmKitLab: { coordinator.show(.alarmKitLab) },
                onOpenDesignGallery: { coordinator.show(.designGallery) }
            )
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
                coordinator: coordinator
            ))
        }
    }

    /// Screens pushed in the Settings tab.
    /// ← CALLED BY: RootView's `.navigationDestination(for: SettingsRoute.self)`
    @ViewBuilder
    func makeScreen(for route: SettingsRoute) -> some View {
        switch route {
        case .alarmKitLab:
            AlarmLabView(viewModel: AlarmLabViewModel(
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler
            ))
        case .designGallery:
            DesignGalleryView()
        }
    }

    // MARK: - Full-screen covers

    @ViewBuilder
    func makeScreen(for route: FullScreenRoute) -> some View {
        switch route {
        case .ringing(let alarmID):
            RingingPlaceholderView(viewModel: RingingPlaceholderViewModel(
                alarmID: alarmID,
                repository: dependencies.alarmRepository,
                scheduler: dependencies.alarmScheduler,
                coordinator: coordinator
            ))
        }
    }
}
