//
//  RingingViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #14 Ringing, #15 Missions, #16 Success, all one full-screen flow)
//  WHAT:  Runs a wake-up from start to finish:
//           ringing ──(Start Mission)──▶ mission 1 … mission N ──▶ success
//           ringing ──(I'm up)──────────────────────────────────▶ success
//           ringing ──(Snooze)──▶ screen closes, rings again in X minutes
//  DATA:  reads WakeAlarm (→ RingInfo snapshot), writes WakeRecord (history),
//         may switch off / delete a one-time alarm when done.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .ringing(alarmID:))
//    ← OPENED BY:  "Start Mission" on the lock screen → StartMissionIntent → AlarmLaunchRouter → RootView
//                  RootView after a sync finds an alarm ringing (AlarmSyncService.ringingAlarmID)
//                  Alarm List "Finish your mission" banner (AlarmListViewModel.resumeMission)
//    → iOS:     AlarmScheduling.stopRinging / scheduleSnooze / missionCompleted
//    → AUDIO:   AudioPlaying.startAlarm / setAlarmMuted / stopAlarm
//    → DATA:    AlarmRepository (fetch, save, delete), WakeRecordRepository (openRecord, save)
//    → MISSIONS: MissionView → (Math|Typing|Shake)MissionViewModel → missionFinished()/userInteracted()
//    → CLOSE:   AppCoordinator.dismissFullScreen()
//
//  WHY the app plays its OWN sound here: "Start Mission" silences iOS's alarm (otherwise
//  it would keep ringing over the mission). From that moment, RiseUp itself must keep
//  the user awake, or they'd put the phone down and sleep.
//

import Foundation
import Observation
import UIKit

@Observable
final class RingingViewModel {

    // MARK: - Types

    enum Phase: Equatable {
        case ringing
        case mission(index: Int)
        case success(WakeSummary)
    }

    /// Everything the screen shows about the alarm, copied out of the WakeAlarm
    /// (Views never hold live database objects; see AlarmRow.swift).
    struct RingInfo: Equatable {
        let title: String
        let missions: [MissionDraft]
        let sound: AlarmSound
        let isSnoozeEnabled: Bool
        let snoozeMinutes: Int
        let maxSnoozeCount: Int
        /// The wallpaper behind this alarm (its own choice or the Settings default; "Surprise" already resolved).
        var wallpaper: Wallpaper = .standard
    }

    /// Shown on the success screen.
    struct WakeSummary: Equatable {
        let wokeAt: Date
        let missionSeconds: Double
        let missionsCompleted: Int
        let snoozeCount: Int
        /// > 0 → "We'll check on you in N minutes" (Wake-Up Check, #18).
        var wakeUpCheckMinutes: Int = 0
    }

    // MARK: - State the View reads

    private(set) var phase: Phase = .ringing
    /// `nil` if the alarm no longer exists (deleted while ringing).
    private(set) var info: RingInfo?
    /// True while missions keep the alarm quiet; false when it's ringing at you.
    private(set) var isQuiet = false
    /// True when the user stopped interacting during a mission and the alarm came back.
    private(set) var isIdleWarning = false
    private(set) var snoozeCount = 0
    private(set) var errorMessage: String?
    /// Morning check-in (#17), chosen on the success screen.
    private(set) var mood: Mood?
    /// When the alarm started ringing on this screen: the wallpaper's energy ramp starts here.
    private(set) var ringStartedAt = Date.now
    /// The decoded photo when the wallpaper is one of the user's photos.
    private(set) var wallpaperPhoto: UIImage?

    var currentMission: MissionDraft? {
        if case .mission(let index) = phase, let info, index < info.missions.count {
            return info.missions[index]
        }
        return nil
    }

    var missionNumberText: String {
        if case .mission(let index) = phase, let info {
            return "Mission \(index + 1) of \(info.missions.count)"
        }
        return ""
    }

    /// Snooze is offered only for alarms WITHOUT missions, and only up to the limit.
    var canSnooze: Bool {
        guard let info, info.missions.isEmpty, info.isSnoozeEnabled else { return false }
        return snoozeCount < info.maxSnoozeCount
    }

    var snoozesLeft: Int {
        guard let info else { return 0 }
        return max(0, info.maxSnoozeCount - snoozeCount)
    }

    // MARK: - Dependencies

    let alarmID: UUID
    /// The sensors the missions need (handed to MissionView by the View).
    let missionServices: MissionServices
    private let repository: AlarmRepository
    private let records: WakeRecordRepository
    private let scheduler: any AlarmScheduling
    private let audio: any AudioPlaying
    private let timeAnnouncer: any TimeAnnouncing
    private let sleepSounds: any SleepSoundPlaying
    private let settings: AppSettings
    private let wallpaperStore: any WallpaperStoring
    private let coordinator: AppCoordinator

    private var record: WakeRecord?
    private var missionStartedAt: Date?
    private var lastInteraction = Date.now
    private var watchdog: Task<Void, Never>?
    /// When the time was last spoken ("Time Pressure"). `nil` = not yet in this wake-up.
    private var lastAnnouncement: Date?
    private var hasStarted = false
    /// WHY (found in code review): a double tap on "I'm up", or a mission reporting "done"
    /// twice, could run finish() twice at once: backups re-armed twice, the record saved twice.
    private var isFinishing = false
    /// True while a snooze is being scheduled (the button is disabled meanwhile).
    private(set) var isSnoozing = false
    /// Missions that were swapped for Math (sensor missing, or "Can't match?").
    private var replacedMissionIndices: Set<Int> = []

    /// Seconds without touching the screen before the alarm comes back during the CURRENT
    /// mission: 15 s for most, longer for walking missions (→ MissionType.idleSecondsAllowed).
    /// TRY: return 5 here and watch the alarm come back quickly when you stop.
    var idleSecondsBeforeAlarmReturns: TimeInterval {
        // A mission replaced by Math is a Math mission now: no walking, so the normal 15 s.
        if case .mission(let index) = phase, replacedMissionIndices.contains(index) { return 15 }
        return currentMission?.type.idleSecondsAllowed ?? 15
    }

    init(alarmID: UUID, repository: AlarmRepository, records: WakeRecordRepository,
         scheduler: any AlarmScheduling, audio: any AudioPlaying,
         timeAnnouncer: any TimeAnnouncing, sleepSounds: any SleepSoundPlaying, settings: AppSettings,
         wallpaperStore: any WallpaperStoring, missionServices: MissionServices, coordinator: AppCoordinator) {
        self.alarmID = alarmID
        self.repository = repository
        self.records = records
        self.scheduler = scheduler
        self.audio = audio
        self.timeAnnouncer = timeAnnouncer
        self.sleepSounds = sleepSounds
        self.settings = settings
        self.wallpaperStore = wallpaperStore
        self.missionServices = missionServices
        self.coordinator = coordinator
    }

    // MARK: - Start

    /// ← CALLED BY: RingingView `.onAppear`
    func start() {
        guard !hasStarted else { return }     // onAppear can fire more than once
        hasStarted = true

        guard let alarm = try? repository.fetch(id: alarmID) else { return }
        info = RingInfo(
            title: alarm.displayTitle,
            missions: alarm.sortedMissions.map(MissionDraft.init),  // → MissionDraft.init(_ config:) copies every field, payloads too
            sound: AlarmSound.from(alarm.soundName),
            isSnoozeEnabled: alarm.isSnoozeEnabled,
            snoozeMinutes: alarm.snoozeMinutes,
            maxSnoozeCount: alarm.maxSnoozeCount,
            wallpaper: (alarm.wallpaperID.flatMap(Wallpaper.init(rawValue:)) ?? settings.defaultWallpaper).resolved()
        )
        ringStartedAt = .now
        loadWallpaperPhoto()                          // → WallpaperStore (background), usually instant

        // 1. iOS's alarm off, ours on. (WHY: see the header comment.)
        // Rain sounds from the night before must not play over the alarm. → SleepSoundPlayer
        sleepSounds.stopAll()
        scheduler.stopRinging(alarm)
        audio.startAlarm(AlarmSound.from(alarm.soundName), rampUp: true)

        // 2. History: continue an unfinished record (after a snooze) or start a new one.
        record = try? records.openRecord(alarmID: alarm.id, alarmTitle: alarm.displayTitle)
        snoozeCount = record?.snoozeCount ?? 0
    }

    // MARK: - Ringing actions

    /// ← CALLED BY: "Start Mission"
    func startMissions() {
        guard let info, !info.missions.isEmpty else { return }
        missionStartedAt = .now
        phase = .mission(index: 0)
        quietAlarm()
        startWatchdog()
    }

    /// ← CALLED BY: "I'm up" (alarms without missions)
    func dismiss() async {
        await finish()
    }

    /// ← CALLED BY: "Snooze"
    func snooze() async {
        // WHY `isSnoozing` (found in the review): two quick taps used to schedule TWO snoozes
        // and count 2 against the limit.
        guard !isSnoozing, canSnooze, let info, let alarm = try? repository.fetch(id: alarmID) else { return }
        isSnoozing = true
        defer { isSnoozing = false }
        do {
            try await scheduler.scheduleSnooze(for: alarm, minutes: info.snoozeMinutes)
            snoozeCount += 1
            record?.snoozeCount = snoozeCount
            try? records.save()
            audio.stopAlarm()
            coordinator.dismissFullScreen()          // → rings again in snoozeMinutes
        } catch {
            errorMessage = "Couldn't snooze. \(error.localizedDescription)"
        }
    }

    // MARK: - Mission callbacks (from the mission ViewModels)

    /// Any tap/keypress/shake. Keeps the alarm quiet while the user is active.
    func userInteracted() {
        lastInteraction = .now
        if isIdleWarning {
            isIdleWarning = false
            quietAlarm()
        }
    }

    /// The current mission was swapped for Math by MissionView (its safety net).
    /// ← CALLED BY: MissionView's `onReplaced` (via RingingView)
    func currentMissionReplaced() {
        if case .mission(let index) = phase { replacedMissionIndices.insert(index) }
        lastInteraction = .now
    }

    /// The current mission is solved → next one, or success after the last.
    func missionFinished() {
        guard case .mission(let index) = phase, let info else { return }
        lastInteraction = .now
        if index + 1 < info.missions.count {
            phase = .mission(index: index + 1)
        } else {
            Task { await finish() }
        }
    }

    // MARK: - Wallpaper (#32)

    /// How long the wallpaper takes to go from calm to "wide awake". TRY: 20 for a faster build-up.
    static let wallpaperRampSeconds: TimeInterval = 40

    private func loadWallpaperPhoto() {
        guard case .photo(let id) = info?.wallpaper else { return }
        Task { wallpaperPhoto = await wallpaperStore.image(for: id) }
    }

    // MARK: - Success / close

    /// ← CALLED BY: a mood button on the success screen (Morning check-in, #17)
    /// → WakeRecordRepository.setMood → WakeRecord.moodRawValue → Morning tab & Stats
    func setMood(_ newMood: Mood) {
        mood = newMood
        guard let record else { return }
        try? records.setMood(newMood, forRecordID: record.id)
    }

    /// ← CALLED BY: "Start my day" on the success screen
    func close() {
        coordinator.dismissFullScreen()
    }

    #if DEBUG
    /// Debug-only escape hatch so testing can't get stuck. Not in App Store builds.
    func debugClose() {
        stopWatchdog()
        audio.stopAlarm()
        coordinator.dismissFullScreen()
    }
    #endif

    func dismissError() { errorMessage = nil }

    // MARK: - Private

    private func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        stopWatchdog()
        audio.stopAlarm()

        let now = Date.now
        let seconds = missionStartedAt.map { now.timeIntervalSince($0) } ?? 0
        let missionCount = info?.missions.count ?? 0
        var checkMinutes = 0

        if let alarm = try? repository.fetch(id: alarmID) {
            // Stop the backup chain (and snooze), and arm tomorrow's chain for repeating alarms.
            try? await scheduler.missionCompleted(for: alarm)
            // Wake-Up Check: one more "are you up?" alarm in a few minutes, if switched on.
            // (Never for quick alarms: they're deleted just below, and their check with them.)
            if alarm.wakeUpCheckMinutes > 0 && !alarm.isQuickAlarm {
                do {
                    try await scheduler.scheduleWakeUpCheck(for: alarm, minutes: alarm.wakeUpCheckMinutes)
                    checkMinutes = alarm.wakeUpCheckMinutes
                } catch {
                    checkMinutes = 0                 // couldn't schedule: don't promise it on screen
                }
            }
            if alarm.isQuickAlarm {
                scheduler.cancel(alarm)
                try? repository.delete(alarm)        // quick alarms are throwaway
            } else if !alarm.isRepeating {
                alarm.isEnabled = false              // one-time alarm: done, like the iOS Clock app
                try? repository.save()
            }
        }

        record?.dismissedAt = now
        record?.missionsCompleted = missionCount
        record?.missionSeconds = seconds
        try? records.save()

        phase = .success(WakeSummary(
            wokeAt: now, missionSeconds: seconds, missionsCompleted: missionCount, snoozeCount: snoozeCount,
            wakeUpCheckMinutes: checkMinutes
        ))
    }

    private func quietAlarm() {
        isQuiet = true
        audio.setAlarmMuted(true)
    }

    /// Every second during missions: if the user went idle, bring the alarm back.
    private func startWatchdog() {
        stopWatchdog()
        lastInteraction = .now
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if case .mission = self.phase,
                   !self.isIdleWarning,
                   Date.now.timeIntervalSince(self.lastInteraction) > self.idleSecondsBeforeAlarmReturns {
                    self.isIdleWarning = true
                    self.isQuiet = false
                    self.audio.setAlarmMuted(false)   // → it rings again until they continue
                }
                // WHY (found in the code review): a long mission (walking, hard maths…) ran into the
                // +1/+2/+3 min backups, and iOS's alert popped over the mission. While the user is
                // busy IN the app, silence them. `stop` (not cancel): later backups stay armed in
                // case the user leaves the app without finishing.
                if case .mission = self.phase, let alarm = try? self.repository.fetch(id: self.alarmID) {
                    self.scheduler.stopRinging(alarm)  // → AlarmKit: only stops ones that are ringing
                }
                self.announceTimeIfDue()
            }
        }
    }

    private func stopWatchdog() {
        watchdog?.cancel()
        watchdog = nil
        timeAnnouncer.stop()
    }

    /// "Time Pressure": speak the time when missions start, then once a minute.
    /// Only while the alarm itself is quiet (otherwise nobody would hear the voice).
    /// → TimeAnnouncer (AVSpeechSynthesizer). Switched on/off in Settings.
    private func announceTimeIfDue(now: Date = .now) {
        guard settings.speaksTimeWhileRinging, isQuiet, case .mission = phase else { return }
        if let last = lastAnnouncement, now.timeIntervalSince(last) < 60 { return }
        lastAnnouncement = now
        timeAnnouncer.announce(now)
    }
}
