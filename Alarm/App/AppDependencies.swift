//
//  AppDependencies.swift
//  RiseUp
//
//  LAYER: App
//  WHAT:  The "toolbox" holding every shared service and repository.
//  USED BY: RiseUpApp (creates it), ScreenFactory (hands tools to ViewModels).
//
//  LEARN: Dependency Injection (DI)
//  ────────────────────────────────
//  Instead of each ViewModel creating its own database or scheduler, we create them
//  ONCE here and pass them in ("inject" them). Benefits:
//   • one shared database context, so no out-of-sync copies
//   • previews/tests can inject fakes (`.preview()`)
//   • you can see every dependency of a ViewModel in its `init`
//

import Foundation
import Observation
import SwiftData

@Observable         //use observable when values of ViewModel change, and we're required to update the value of UI
final class AppDependencies {   //use final for really final and stopping to use this class for inheritence
    let modelContainer: ModelContainer
    let alarmRepository: AlarmRepository
    let alarmScheduler: any AlarmScheduling

    init(modelContainer: ModelContainer, alarmScheduler: any AlarmScheduling) {
        self.modelContainer = modelContainer
        self.alarmRepository = AlarmRepository(context: modelContainer.mainContext)
        self.alarmScheduler = alarmScheduler
    }

    /// The real app: database on disk + real AlarmKit.
    static func live() -> AppDependencies {
        do {
            return AppDependencies(
                modelContainer: try ModelContainerFactory.make(),
                alarmScheduler: AlarmKitScheduler()
            )
        } catch {
            // WHY crash here? Without its database the app can't do anything useful, and
            // this should only fail from a programming mistake (e.g. a bad migration).
            // Phase 7 adds a friendlier recovery screen before release.
            fatalError("RiseUp could not open its database: \(error)")
        }
    }

    /// Previews & tests: in-memory database + fake scheduler. Never touches real data or alarms.
    static func preview() -> AppDependencies {
        // LEARN: `try!` crashes on error. Acceptable ONLY in preview/test helpers,
        // where an in-memory database can't realistically fail.
        AppDependencies(
            modelContainer: try! ModelContainerFactory.make(inMemory: true),
            alarmScheduler: MockAlarmScheduler()
        )
    }
}
