//
//  Trace.swift
//  RiseUp
//
//  LAYER: Service (a learning + debugging tool)
//  WHAT:  One-line "🔎" messages at the important junctions of every big feature, so you can WATCH a
//         feature run in Xcode's console: which file runs, in which order, with which values.
//  DATA:  none (writes to Apple's unified log).
//
//  CONNECTIONS:
//    ← CALLED BY: AlarmEditorViewModel, AlarmKitScheduler, StartMissionIntent, AlarmLaunchRouter,
//                 AppCoordinator, RingingViewModel, AlarmSyncService, WidgetBridge, AudioService,
//                 WallpaperPickerViewModel, SettingsViewModel
//    → WRITES:    os.Logger (subsystem "com.riseup.trace") → Xcode console / Console.app
//
//  HOW TO USE IT (docs/DEBUGGING_GUIDE.md has the full walkthrough)
//  ──────────────────────────────────────────────────────────────
//  • Run from Xcode → the console (⇧⌘Y) shows lines like
//      🔎 [ring] RingingViewModel.start() → stopRinging + our sound + keep-alive
//    Type "🔎" or "[ring]" in the console's filter box to see only one feature.
//  • Alarms launch RiseUp WITHOUT Xcode (from the lock screen). To still see the trace: plug the iPhone
//    into the Mac → open Console.app → choose the iPhone → Action menu: "Include Debug Messages" → search
//    `subsystem:com.riseup.trace` → let the alarm ring.
//
//  LEARN: `os.Logger` is Apple's logging system. Unlike `print`, it's fast, it works when the app wasn't
//  started by Xcode, and every line is tagged with a time, a subsystem and a category you can filter on.
//  `.debug` messages cost almost nothing and aren't stored on the iPhone, so they're fine in the App Store build.
//

import Foundation
import os

nonisolated enum Trace {
    /// Which feature a line belongs to: the word in [brackets] you can filter on.
    enum Area: String {
        case editor, scheduler, ring, nav, sync, widget, wallpaper, audio, theme
    }

    /// Writes one trace line. Keep messages short: "Type.method() → what happens next".
    /// WHY no alarm titles in messages: they're the user's words; ids (first 8 characters) are enough.
    static func log(_ area: Area, _ message: String) {
        Logger(subsystem: "com.riseup.trace", category: area.rawValue)
            .debug("🔎 [\(area.rawValue, privacy: .public)] \(message, privacy: .public)")
    }

    /// "3F2A9C1B": the first 8 characters of an id, enough to tell alarms apart in the console.
    static func short(_ id: UUID) -> String { String(id.uuidString.prefix(8)) }
}
