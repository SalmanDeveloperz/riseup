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
            ComingSoonView(
                title: "Alarms",
                systemImage: AppTab.alarms.systemImage,
                phase: 1,
                message: "Your alarm list with glowing cards, a countdown to the next alarm and quick alarms.",
                showsLiveClock: true
            )
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
