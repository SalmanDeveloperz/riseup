//
//  AlarmLaunchRouter.swift
//  RiseUp
//
//  LAYER: Coordinator (bridge from system events to the UI)
//  WHAT:  A tiny "mailbox": StartMissionIntent drops an alarm ID in it, RootView picks it up.
//  USED BY: StartMissionIntent (writes), RootView (reads → tells AppCoordinator).
//

import Foundation
import Observation

/// Holds a pending "show the mission screen for alarm X" request.
///
/// WHY a shared singleton (`.shared`)? iOS creates `StartMissionIntent` itself, outside
/// our SwiftUI view tree, so the intent can't reach our `AppCoordinator` instance.
/// This one tiny shared object is the meeting point. Everything else in the app
/// uses dependency injection, not singletons.
@Observable
final class AlarmLaunchRouter {
    static let shared = AlarmLaunchRouter()

    /// The alarm whose mission screen should open, or `nil` when there's nothing to do.
    private(set) var pendingAlarmID: UUID?

    /// LEARN: `private init()` stops anyone else from creating a second router.
    private init() {}

    /// Called by StartMissionIntent.
    func requestRinging(for alarmID: UUID) {
        pendingAlarmID = alarmID
    }

    /// Returns the pending request and clears it, so it's handled exactly once.
    func consumePendingAlarmID() -> UUID? {
        defer { pendingAlarmID = nil }   // LEARN: `defer` runs right before the function returns.
        return pendingAlarmID
    }
}
