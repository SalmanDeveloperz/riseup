//
//  WidgetSnapshot.swift
//  RiseUp
//
//  LAYER: Shared (compiled into BOTH the app and the RiseUpWidgets extension)
//  WHAT:  "Your next alarms", as a small list the widgets can show without the database:
//         time, title, missions, sound and a picture of each alarm's wallpaper.
//  DATA:  the App Group (a folder + UserDefaults that the app AND the widget may open):
//           • UserDefaults(suiteName: appGroupID)["widgetSnapshot.v1"] → this struct as JSON
//           • <group folder>/Wallpapers/wp1-<wallpaper>.jpg            → still pictures
//
//  CONNECTIONS:
//    ← WRITTEN BY: WidgetBridge (app) after every sync and when RiseUp goes to the background
//    → READ BY:    RiseUpWidgets/NextAlarmWidget (home + lock screen widgets)
//
//  WHY not share the SwiftData database: the widget would need the whole model layer and a
//  database moved into the group folder (a risky migration). A snapshot is tiny, can't be
//  corrupted by the widget, and is all a widget needs. iOS also wakes widgets rarely, so they
//  must never do slow work: everything here is ready to draw.
//

import Foundation

/// Names both programs must agree on.
nonisolated enum WidgetShared {
    /// Must match `com.apple.security.application-groups` in Config/Alarm.entitlements AND
    /// Config/RiseUpWidgets.entitlements.
    static let appGroupID = "group.com.testProject.Alarm"
    /// The widget's `kind` (its ID inside iOS). WidgetBridge reloads it by this name.
    static let nextAlarmKind = "RiseUpNextAlarm"
    /// LEARN: the ".v1" lets us change the format later without reading old data wrongly.
    static let snapshotKey = "widgetSnapshot.v1"

    /// The shared UserDefaults, or nil if the App Group isn't set up (then widgets say "Open RiseUp").
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// The shared folder for the wallpaper pictures, created when needed.
    static var wallpaperFolder: URL? {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let folder = group.appending(path: "Wallpapers", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// "live.kyotoBlossoms" → "wp1-live.kyotoBlossoms.jpg".
    /// TRY: bump "wp1" to "wp2" after changing how a wallpaper looks, so every picture is redrawn.
    static func wallpaperFileName(for wallpaperID: String) -> String {
        "wp1-\(wallpaperID.replacingOccurrences(of: "/", with: "-")).jpg"
    }

    /// Links the widgets open (the app handles them in RootView `.onOpenURL` → DeepLink).
    static let newAlarmURL = URL(string: "riseup://new")!
    static func alarmURL(_ id: UUID) -> URL { URL(string: "riseup://alarm/\(id.uuidString)")! }
    static func napURL(minutes: Int) -> URL { URL(string: "riseup://nap/\(minutes)")! }
}

/// Everything the widgets show.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The next rings of all switched-on alarms, earliest first (about a week ahead).
    var upcoming: [WidgetAlarmEvent]
    /// When the app wrote this (shown nowhere; handy when debugging).
    var writtenAt: Date

    /// The rings still to come after `date` (the widget moves on by itself after each alarm).
    func upcoming(after date: Date) -> [WidgetAlarmEvent] {
        upcoming.filter { $0.fireDate > date }
    }

    // MARK: Reading & writing

    /// ← CALLED BY: the widget's timeline provider. nil = the app never wrote one (or no App Group).
    static func load() -> WidgetSnapshot? {
        guard let data = WidgetShared.defaults?.data(forKey: WidgetShared.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// ← CALLED BY: WidgetBridge. Returns true if something changed (then the widgets reload).
    @discardableResult
    func save() -> Bool {
        guard let defaults = WidgetShared.defaults else { return false }
        // Compare without `writtenAt`, so an unchanged list doesn't wake the widgets for nothing.
        if let old = Self.load(), old.upcoming == upcoming { return false }
        guard let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: WidgetShared.snapshotKey)
        return true
    }
}

/// One future ring of one alarm.
nonisolated struct WidgetAlarmEvent: Codable, Equatable, Identifiable, Sendable {
    var alarmID: UUID
    var fireDate: Date
    var title: String
    /// SF Symbol names of the alarm's missions, in order ("function", "figure.walk"…).
    var missionSymbols: [String]
    var soundTitle: String
    /// "Kyoto Blossoms"
    var wallpaperTitle: String
    /// The picture file in `WidgetShared.wallpaperFolder` (nil if it couldn't be made).
    var wallpaperFile: String?

    var id: String { "\(alarmID.uuidString)-\(fireDate.timeIntervalSinceReferenceDate)" }
}
