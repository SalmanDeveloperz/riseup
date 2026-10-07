//
//  StartMissionIntent.swift
//  RiseUp
//
//  LAYER: Service (App Intent)
//  WHAT:  Runs when the user taps "Start Mission" on a ringing alarm
//         (lock screen, Dynamic Island or alarm banner).
//  USED BY: AlarmKitScheduler attaches it as the alarm's `secondaryIntent`.
//
//  FLOW:  Alarm rings → user taps "Start Mission" → iOS opens RiseUp and runs
//         `perform()` → we stop the ringing system alarm and ask AlarmLaunchRouter
//         to show the mission screen → RootView sees the request → Coordinator
//         presents the Ringing screen.
//

import AlarmKit
import AppIntents
import Foundation

/// The "Start Mission" button action.
///
/// LEARN: An App Intent is a small action that iOS can run on our behalf (from
/// Shortcuts, Siri, widgets, or here, an alarm button). `LiveActivityIntent` is the
/// kind AlarmKit accepts for its buttons.
struct StartMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Mission"
    static let description = IntentDescription("Opens RiseUp to complete your wake-up mission.")

    /// LEARN: `.foreground` means "open the app when this runs". Missions happen inside RiseUp.
    static let supportedModes: IntentModes = .foreground

    /// WHY Strings instead of UUIDs: App Intent parameters must be simple types the
    /// system can store. We convert back to UUID in `perform()`.

    /// The `WakeAlarm.id` whose missions should start.
    @Parameter(title: "Alarm ID")
    var wakeAlarmID: String

    /// The system alarm that is ringing right now (the main alarm or one of its backups).
    @Parameter(title: "Ringing Alarm ID")
    var ringingSystemAlarmID: String

    /// LEARN: App Intents need an empty `init()` so the system can rebuild them later.
    init() {}

    init(wakeAlarmID: UUID, ringingSystemAlarmID: UUID) {
        self.wakeAlarmID = wakeAlarmID.uuidString
        self.ringingSystemAlarmID = ringingSystemAlarmID.uuidString
    }

    /// LEARN: `@MainActor` because we touch AlarmLaunchRouter, which the UI observes.
    @MainActor
    func perform() async throws -> some IntentResult {
        // 1. Silence the system alarm. The app takes over from here.
        // WHY: otherwise it keeps ringing on the lock screen while the user does the mission.
        // (Phase 2 plays the alarm sound inside the app during the mission.)
        if let ringingID = UUID(uuidString: ringingSystemAlarmID) {
            try? AlarmManager.shared.stop(id: ringingID)
        }

        // 2. Ask the UI to show the mission screen for this alarm.
        if let alarmID = UUID(uuidString: wakeAlarmID) {
            AlarmLaunchRouter.shared.requestRinging(for: alarmID)
        }
        return .result()
    }
}
