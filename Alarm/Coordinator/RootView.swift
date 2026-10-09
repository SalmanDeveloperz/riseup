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
//  CONNECTIONS:
//    ← CREATED BY: RiseUpApp (the first and only view RiseUpApp shows)
//    ← READS:      AppDependencies + AppCoordinator from the environment (injected by RiseUpApp)
//                  AlarmLaunchRouter.shared (written by StartMissionIntent)
//    → BINDS:      coordinator.selectedTab  ↔ TabView
//                  coordinator.alarmsPath   ↔ Alarms tab NavigationStack
//                  coordinator.settingsPath ↔ Settings tab NavigationStack
//                  coordinator.sheet        ↔ sheet (sound picker, quick alarm, mission picker)
//                  coordinator.fullScreen   ↔ fullScreenCover (ringing flow)
//    → RUNS:       AlarmSyncService.sync() on launch and every return to the foreground
//    → ASKS:       ScreenFactory to build every screen
//
//  LEARN: "Binding" here means two-way. When code changes `coordinator.alarmsPath`,
//  the stack pushes/pops. When the USER taps the back button, SwiftUI removes the last
//  element from `coordinator.alarmsPath` for us. Both sides always agree.
//

import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppCoordinator.self) private var coordinator

    /// Mailbox for "Start Mission" taps coming from the lock screen.
    private let launchRouter = AlarmLaunchRouter.shared

    /// LEARN: `scenePhase` tells us whether the app is active (on screen), inactive or
    /// in the background. We sync with iOS every time it becomes `.active`.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // LEARN: `@Bindable` lets us create bindings (`$coordinator.selectedTab`) to an
        // @Observable object that came from the environment.
        @Bindable var coordinator = coordinator
        let factory = ScreenFactory(dependencies: dependencies, coordinator: coordinator)

        TabView(selection: $coordinator.selectedTab) {
            Tab(AppTab.alarms.title, systemImage: AppTab.alarms.systemImage, value: AppTab.alarms) {
                // Root = Alarm List. Pushed screens (editor…) come from coordinator.alarmsPath.
                NavigationStack(path: $coordinator.alarmsPath) {
                    factory.makeRoot(for: .alarms)
                        .navigationDestination(for: AlarmsRoute.self) { route in
                            factory.makeScreen(for: route)
                        }
                }
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
        // Shows a sheet whenever `coordinator.sheet` is not nil (sound picker, quick alarm, missions).
        // `onDismiss` also runs when the user swipes the sheet down → forget pending callbacks.
        .sheet(item: $coordinator.sheet, onDismiss: { coordinator.dismissSheet() }) { route in
            factory.makeScreen(for: route)
        }
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
        // Every time the app comes to the front (including the first launch):
        //   1. sync database ↔ iOS (AlarmSyncService)
        //   2. if an alarm is ringing right now, open the Ringing screen automatically
        // WHY: an unanswered alarm keeps ringing forever (spike finding). If the user opens
        // RiseUp instead of tapping "Start Mission", we still take them to the mission.
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            Task {
                await dependencies.alarmSync.sync()
                if coordinator.fullScreen == nil, let ringingID = dependencies.alarmSync.ringingAlarmID() {
                    coordinator.presentRinging(alarmID: ringingID)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppDependencies.preview())
        .environment(AppCoordinator())
}
