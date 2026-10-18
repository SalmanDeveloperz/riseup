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
//    modelContainer        → the SwiftData database file (SchemaV4)
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
//    wallpaperStore        → the user's own alarm-wallpaper photos (FileWallpaperStore / Mock)
//

import Foundation
import Observation
import SwiftData

/// LEARN: `@Observable` here is NOT about values changing (these are all `let`). It's
/// needed because `.environment(object)` only accepts @Observable objects.
/// `final` = nobody can subclass it.
@Observable         //use observable when values of ViewModel   , and we're required to update the value of UI, change properties when used by Views
final class AppDependencies {   //use final for really final and stopping to use this class for inheritence
    let modelContainer: ModelContainer              // store and manage database
    let alarmRepository: AlarmRepository            // handles access to alarm data
    let wakeRecordRepository: WakeRecordRepository
    let alarmScheduler: any AlarmScheduling         // schedule alarms
    let alarmSync: AlarmSyncService
    let audio: any AudioPlaying
    let timeAnnouncer: any TimeAnnouncing
    let missionServices: MissionServices
    let settings: AppSettings
    let sleepSounds: any SleepSoundPlaying
    let bedtimeReminder: any BedtimeReminding
    /// The user's own wallpaper photos (files). → WallpaperStore.swift
    let wallpaperStore: any WallpaperStoring
    /// A message for the user if the database had to be repaired at launch (shown once by RootView).
    /// nil = everything was fine (almost always).
    private(set) var databaseNotice: String?

    init(
        modelContainer: ModelContainer,
        alarmScheduler: any AlarmScheduling,
        audio: any AudioPlaying,
        timeAnnouncer: any TimeAnnouncing,
        missionServices: MissionServices,
        settings: AppSettings,
        sleepSounds: any SleepSoundPlaying,
        bedtimeReminder: any BedtimeReminding,
        wallpaperStore: any WallpaperStoring
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
        self.wallpaperStore = wallpaperStore
    }

    /// The real app: database on disk + real AlarmKit, audio, sensors and camera matching.
    static func live() -> AppDependencies {
        let (container, notice) = openDatabase()
        let settings = AppSettings()
        let dependencies = AppDependencies(
            modelContainer: container,
            alarmScheduler: AlarmKitScheduler(settings: settings),   // reads the Wake-up guarantee
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
            settings: settings,
            sleepSounds: SleepSoundPlayer(),
            bedtimeReminder: NotificationBedtimeReminder(),
            wallpaperStore: FileWallpaperStore()
        )
        dependencies.databaseNotice = notice
        return dependencies
    }

    /// Opens the database, and NEVER crashes the app if that fails.
    ///
    /// WHY (Phase 7, found in the code review): this used to be `fatalError`. A damaged database
    /// file (a full disk, an interrupted update…) would then crash RiseUp on EVERY launch, even
    /// when opened from a ringing alarm. Now, step by step:
    ///   1. open normally (what happens 99.99 % of the time)
    ///   2. try once more (a passing problem, e.g. the disk was busy)
    ///   3. move the damaged file aside (renamed, NOT deleted) and start a fresh database
    ///   4. last resort: a temporary in-memory database, so the app at least opens
    /// For 3 and 4 the user is told what happened (`databaseNotice`).
    private static func openDatabase() -> (ModelContainer, String?) {
        if let container = try? ModelContainerFactory.make() { return (container, nil) }
        if let container = try? ModelContainerFactory.make() { return (container, nil) }
        if (try? ModelContainerFactory.setAsideDamagedStore()) != nil,
           let container = try? ModelContainerFactory.make() {
            return (container, "RiseUp couldn't read its saved data, so it started fresh. Please check your alarms and set them again.")
        }
        // LEARN: `try!` is OK here: an in-memory database needs no file and can't realistically fail.
        let container = try! ModelContainerFactory.make(inMemory: true)
        return (container, "RiseUp can't save data right now (is your iPhone's storage full?). Alarms you set may be lost when the app closes. Free up some space and restart RiseUp.")
    }

    /// ← CALLED BY: RootView after showing `databaseNotice`
    func dismissDatabaseNotice() {
        databaseNotice = nil
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
            bedtimeReminder: MockBedtimeReminder(),
            wallpaperStore: MockWallpaperStore()
        )
    }
}
