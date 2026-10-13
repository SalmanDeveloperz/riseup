//
//  DeveloperTools.swift
//  RiseUp
//
//  LAYER: Coordinator (a SwiftUI environment value)
//  WHAT:  `showsDeveloperTools`: true only in Debug builds with Developer mode on
//         (Settings → tap the version 7 times). Screens use it to show 🐞, "Close (debug)" and
//         "Add sample data" buttons.
//  DATA:  reads AppSettings.showsDeveloperTools (set once in RootView).
//
//  CONNECTIONS:
//    ← SET BY:  RootView (`.environment(\.showsDeveloperTools, …)`)
//    ← READ BY: AlarmListView, RingingView, RecordsView, StatsView
//
//  LEARN: environment values
//  ─────────────────────────
//  `.environment(\.key, value)` hands a value to EVERY view below it (sheets included), without
//  passing it through each init. Perfect for app-wide display flags like this one.
//  `@Entry` writes the boilerplate (EnvironmentKey + getter/setter) for us.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var showsDeveloperTools: Bool = false
}
