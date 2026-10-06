//
//  RootView.swift
//  RiseUp
//
//  LAYER: Coordinator (the top-level View)
//  WHAT:  The tab bar, one NavigationStack per tab, and the full-screen cover.
//         It connects AppCoordinator's state to SwiftUI's navigation views.
//  USED BY: RiseUpApp.
//
//  FLOW OF A NAVIGATION:
//    ViewModel calls coordinator.show(.alarmKitLab)
//      → coordinator.settingsPath gets a new element
//      → NavigationStack(path:) below notices (it's bound with `$`)
//      → it asks `.navigationDestination` which view to show
//      → ScreenFactory builds AlarmLabView + its ViewModel
//

import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppCoordinator.self) private var coordinator

    /// Mailbox for "Start Mission" taps coming from the lock screen.
    private let launchRouter = AlarmLaunchRouter.shared

    var body: some View {
        // LEARN: `@Bindable` lets us create bindings (`$coordinator.selectedTab`) to an
        // @Observable object that came from the environment.
        @Bindable var coordinator = coordinator
        let factory = ScreenFactory(dependencies: dependencies, coordinator: coordinator)

        TabView(selection: $coordinator.selectedTab) {
            Tab(AppTab.alarms.title, systemImage: AppTab.alarms.systemImage, value: AppTab.alarms) {
                NavigationStack { factory.makeRoot(for: .alarms) }
            }

            Tab(AppTab.morning.title, systemImage: AppTab.morning.systemImage, value: AppTab.morning) {
                NavigationStack { factory.makeRoot(for: .morning) }
            }

            Tab(AppTab.sleep.title, systemImage: AppTab.sleep.systemImage, value: AppTab.sleep) {
                NavigationStack { factory.makeRoot(for: .sleep) }
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                NavigationStack(path: $coordinator.settingsPath) {
                    factory.makeRoot(for: .settings)
                        .navigationDestination(for: SettingsRoute.self) { route in
                            factory.makeScreen(for: route)
                        }
                }
            }
        }
        .tint(Theme.Colors.neonPink)
        // Shows a full-screen page whenever `coordinator.fullScreen` is not nil.
        .fullScreenCover(item: $coordinator.fullScreen) { route in
            factory.makeScreen(for: route)
        }
        // WHY `initial: true`: if the app was CLOSED and "Start Mission" launched it, the
        // request arrives before this view exists. `initial` checks once on first appearance too.
        .onChange(of: launchRouter.pendingAlarmID, initial: true) {
            if let alarmID = launchRouter.consumePendingAlarmID() {
                coordinator.presentRinging(alarmID: alarmID)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppDependencies.preview())
        .environment(AppCoordinator())
}
