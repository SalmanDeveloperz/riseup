//
//  BedtimeReminder.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  One daily notification at bedtime: "Time to wind down 🌙".
//  DATA:  none stored here; the time and on/off switch live in AppSettings.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → NotificationBedtimeReminder, preview → Mock)
//    ← USED BY:    SleepViewModel (the Bedtime reminder card)
//    → USES:       UserNotifications (UNUserNotificationCenter)
//
//  LEARN: local notifications
//  ──────────────────────────
//  A "local" notification is scheduled by the app itself, no server needed. A
//  `UNCalendarNotificationTrigger` with only hour + minute and `repeats: true` fires every
//  day at that time, even if RiseUp is closed. Using the same identifier each time means
//  scheduling again REPLACES the old one (no duplicates).
//
//  WHY not AlarmKit for this: a reminder should be a gentle banner, not a ringing alarm.
//

import Foundation
import UserNotifications

protocol BedtimeReminding: AnyObject {
    /// Shows the system "Allow notifications?" popup the first time. Returns whether allowed.
    func requestPermission() async -> Bool
    /// (Re)schedules the daily reminder.
    func schedule(hour: Int, minute: Int) async throws
    func cancel()
}

final class NotificationBedtimeReminder: BedtimeReminding {
    private static let identifier = "riseup.bedtime"

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time to wind down 🌙"
        content.body = "A great morning starts tonight. Put the phone down, or play a sleep sound in RiseUp."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)     // same id → replaces the old one
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

/// Fake for Previews and tests.
final class MockBedtimeReminder: BedtimeReminding {
    var allowsNotifications = true
    private(set) var scheduledTime: (hour: Int, minute: Int)?

    func requestPermission() async -> Bool { allowsNotifications }
    func schedule(hour: Int, minute: Int) async throws { scheduledTime = (hour, minute) }
    func cancel() { scheduledTime = nil }
}
