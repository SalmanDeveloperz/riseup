//
//  RiseUpWidgetsBundle.swift
//  RiseUpWidgets (widget extension)
//
//  LAYER: Widget extension entry point (like RiseUpApp, but for the extension)
//  WHAT:  Lists every widget / Live Activity this extension provides.
//  DATA:  none.
//
//  CONNECTIONS:
//    ← STARTED BY: iOS, when it needs to draw one of our widgets (the app may be closed!)
//    → PROVIDES:   AlarmLiveActivity (lock screen + Dynamic Island alarm UI)
//                  NextAlarmWidget (home screen + lock screen widgets, #31)
//
//  LEARN: A widget extension is a SECOND, tiny program bundled inside the app
//  (RiseUp.app/PlugIns/RiseUpWidgets.appex). iOS runs it on its own to draw widgets
//  and Live Activities. It can't call app code, so anything both need lives in /Shared.
//
//  WHY AlarmKit needs this: an alarm that rings while the phone is UNLOCKED, or is
//  snoozing, is shown as a Live Activity. Without a widget extension iOS has nothing
//  to draw, and those alarms may not appear at all.
//

import SwiftUI
import WidgetKit

/// LEARN: `@main` marks where a program starts. The app has its own `@main` (RiseUpApp);
/// this one is the extension's.
@main
struct RiseUpWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
        NextAlarmWidget()       // the "Next alarm" widget in the home/lock screen widget gallery
    }
}
