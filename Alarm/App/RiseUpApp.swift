//
//  RiseUpApp.swift
//  RiseUp
//
//  LAYER: App (entry point)
//  WHAT:  Where the app starts. Creates the shared objects and shows RootView.
//
//  START READING HERE. The order of the app:
//    RiseUpApp → creates AppDependencies (database + services) and AppCoordinator (navigation)
//              → puts both in the SwiftUI "environment" so any view can reach them
//              → shows RootView (tabs)
//

import SwiftUI

/// LEARN: `@main` marks the single starting point of the program.
@main   // Entry point
struct RiseUpApp: App {
    /// LEARN: `@State` here means "create ONCE and keep for the app's whole life".
    @State private var dependencies = AppDependencies.live()
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
//            VStack{
//                Image("logo")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 200, height: 200)
//            }
            
            RootView()
                // LEARN: `.environment(object)` makes an @Observable object available to
                // every view below. They read it with `@Environment(Type.self)`.
                //We're injecting AppDependencies and AppCoordinator via .environment
                .environment(dependencies)
                .environment(coordinator)
                // Settings → Appearance (#35): System / Light / Dark. `nil` = follow the iPhone.
                // (System by default. The Ringing flow and widgets always stay dark.)
                .preferredColorScheme(dependencies.settings.appearance.colorScheme)
                // WHY `.id`: colours are read when a view is drawn; a new palette must redraw EVERYTHING.
                // LEARN: changing a view's `.id` makes SwiftUI throw it away and build it fresh. Navigation
                // survives because it lives in AppCoordinator, not in the views.
                .id(dependencies.settings.palette)
        }
    }
}
