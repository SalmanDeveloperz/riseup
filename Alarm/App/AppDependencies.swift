//
//  AppDependencies.swift
//  RiseUp
//
//  LAYER: App
//  WHAT:  The "toolbox" holding every shared service and repository.
//  USED BY: RiseUpApp (creates it), ScreenFactory (hands tools to ViewModels),
//           RootView (runs the sync on launch / foreground).
//
//  LEARN: Dependency Injection (DI)
//  ────────────────────────────────
//  Instead of each ViewModel creating its own database or scheduler, we create them
//  ONCE here and pass them in ("inject" them). Benefits:
//   • one shared database context, so no out-of-sync copies
//   • previews/tests can inject fakes (`.preview()`)
//   • you can see every dependency of a ViewModel in its `init`
//
//  CONNECTIONS (what's inside the toolbox):
//    modelContainer        → the SwiftData database file (SchemaV2)
//    alarmRepository       → WakeAlarm rows        (AlarmRepository)
//    wakeRecordRepository  → wake-up history rows  (WakeRecordRepository)
//    alarmScheduler        → iOS system alarms     (AlarmKitScheduler / MockAlarmScheduler)
//    alarmSync             → keeps database & iOS in agreement (AlarmSyncService)
//    audio                 → sounds inside the app (AudioService / MockAudioService)
//    timeAnnouncer         → speaks the time during missions (SpeechTimeAnnouncer / Mock)
//    missionServices       → sensors + camera matching for missions (MissionServices)
//    settings              → small preferences in UserDefaults (AppSettings)
//    sleepSounds           → the sleep-sound mixer + sleep timer (SleepSoundPlayer / Mock)
//    bedtimeReminder       → the daily "time to wind down" notification (NotificationBedtimeReminder / Mock)
//

import Foundation
import Observation
import SwiftData

/// LEARN: `@Observable` here is NOT about values changing (these are all `let`). It's
/// needed because `.environment(object)` only accepts @Observable objects.
/// `final` = nobody can subclass it.
@Observable
final class AppDependencies {
    let modelContainer: ModelContainer
    let alarmRepository: AlarmRepository
    let wakeRecordRepository: WakeRecordRepository
    let alarmScheduler: any AlarmScheduling
    let alarmSync: AlarmSyncService
    let audio: any AudioPlaying
    let timeAnnouncer: any TimeAnnouncing
    let missionServices: MissionServices
    let settings: AppSettings
    let sleepSounds: any SleepSoundPlaying
    let bedtimeReminder: any BedtimeReminding

    init(
        modelContainer: ModelContainer,
        alarmScheduler: any AlarmScheduling,
        audio: any AudioPlaying,
        timeAnnouncer: any TimeAnnouncing,
        missionServices: MissionServices,
        settings: AppSettings,
        sleepSounds: any SleepSoundPlaying,
        bedtimeReminder: any BedtimeReminding
    ) {
        self.modelContainer = modelContainer
        self.alarmRepository = AlarmRepository(context: modelContainer.mainContext)
        self.wakeRecordRepository = WakeRecordRepository(context: modelContainer.mainContext)
        self.alarmScheduler = alarmScheduler
        // The sync service is built FROM two other tools: repository + scheduler.
        self.alarmSync = AlarmSyncService(repository: alarmRepository, scheduler: alarmScheduler)
        self.audio = audio
        self.timeAnnouncer = timeAnnouncer
        self.missionServices = missionServices
        self.settings = settings
        self.sleepSounds = sleepSounds
        self.bedtimeReminder = bedtimeReminder
    }

    /// The real app: database on disk + real AlarmKit, audio, sensors and camera matching.
    static func live() -> AppDependencies {
        do {
            return AppDependencies(
                modelContainer: try ModelContainerFactory.make(),
                alarmScheduler: AlarmKitScheduler(),
                audio: AudioService(),
                timeAnnouncer: SpeechTimeAnnouncer(),
                missionServices: MissionServices(
                    shake: CoreMotionShakeDetector(),
                    steps: CoreMotionStepCounter(),
                    squat: CoreMotionSquatDetector(),
                    // WHY the switch: Vision's photo fingerprints don't work in the Simulator
                    // (see PixelPhotoMatcher). Real iPhones always use Vision.
                    photoMatcher: MissionEnvironment.isSimulator ? PixelPhotoMatcher() : VisionPhotoMatcher()
                ),
                settings: AppSettings(),
                sleepSounds: SleepSoundPlayer(),
                bedtimeReminder: NotificationBedtimeReminder()
            )
        } catch {
            // WHY crash here? Without its database the app can't do anything useful, and
            // this should only fail from a programming mistake (e.g. a bad migration).
            // Phase 7 adds a friendlier recovery screen before release.
            fatalError("RiseUp could not open its database: \(error)")
        }
    }

    /// Previews & tests: in-memory database + fakes. Never touches real data, alarms or speakers.
    static func preview() -> AppDependencies {
        // LEARN: `try!` crashes on error. Acceptable ONLY in preview/test helpers,
        // where an in-memory database can't realistically fail.
        AppDependencies(
            modelContainer: try! ModelContainerFactory.make(inMemory: true),
            alarmScheduler: MockAlarmScheduler(),
            audio: MockAudioService(),
            timeAnnouncer: MockTimeAnnouncer(),
            missionServices: .preview(),
            // A throwaway settings store, so previews never change the real app's settings.
            settings: AppSettings(store: UserDefaults(suiteName: "RiseUpPreview") ?? .standard),
            sleepSounds: MockSleepSoundPlayer(),
            bedtimeReminder: MockBedtimeReminder()
        )
    }
}
