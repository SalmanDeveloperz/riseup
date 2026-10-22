//
//  SleepViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #19 Sleep sounds, the Sleep tab's root)
//  WHAT:  Tap sounds to mix up to 3 (rain + fire + fan…), see what's playing, reopen the last
//         mix in one tap, and set a daily bedtime reminder.
//  DATA:  reads the live mix from SleepSoundPlayer; reads/writes AppSettings (last mix,
//         bedtime reminder); schedules/cancels the reminder notification.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeRoot(for: .sleep)
//    → AUDIO:      SleepSoundPlaying.toggle / setVolume (the mixer service)
//    → SETTINGS:   AppSettings.lastSleepMix, bedtimeReminderOn, bedtimeMinuteOfDay
//    → REMINDER:   BedtimeReminding.requestPermission / schedule / cancel
//    → NAVIGATES:  AppCoordinator.presentSleepPlayer() (Now Playing sheet, #20)
//

import Foundation
import Observation

@Observable
final class SleepViewModel {
    private let player: any SleepSoundPlaying
    private let settings: AppSettings
    private let reminder: any BedtimeReminding
    private let coordinator: AppCoordinator

    /// A short message for the View (e.g. "mix full"). Cleared by the View after a moment.
    private(set) var message: String?

    /// Counts taps on the reminder switch, so a slow answer from an OLD tap can't win (see setReminder).
    @ObservationIgnored private var reminderRequest = 0

    init(player: any SleepSoundPlaying, settings: AppSettings,
         reminder: any BedtimeReminding, coordinator: AppCoordinator) {
        self.player = player
        self.settings = settings
        self.reminder = reminder
        self.coordinator = coordinator
    }

    // MARK: - Mix (reads the player: single source of truth)

    let categories = SleepSound.Category.allCases

    func isActive(_ sound: SleepSound) -> Bool { player.activeSounds.contains(sound) }
    var hasMix: Bool { !player.activeSounds.isEmpty }
    var isPlaying: Bool { player.isPlaying }
    var mixTitle: String { player.activeSounds.map(\.title).joined(separator: " + ") }
    var timerEndsAt: Date? { player.timerEndsAt }

    /// "Play last mix" appears when nothing is playing but a mix was saved earlier.
    var canPlayLastMix: Bool { !hasMix && !settings.lastSleepMix.isEmpty }

    /// ← CALLED BY: tapping a sound tile
    func toggle(_ sound: SleepSound) {
        if player.toggle(sound) {                          // → SleepSoundPlayer (fade in/out)
            saveMix()
        } else if player.activeSounds.count >= sleepMixMaxSounds {
            message = "Up to \(sleepMixMaxSounds) sounds at once. Tap a playing one to remove it."
        } else {
            message = "\(sound.title) couldn't be played. Please try another sound."
        }
    }

    func togglePause() {
        if player.isPaused { player.resume() } else { player.pause() }
    }

    /// ← CALLED BY: "Play last mix"
    func playLastMix() {
        for (raw, volume) in settings.lastSleepMix.sorted(by: { $0.key < $1.key }) {
            guard let sound = SleepSound(rawValue: raw),            // a removed sound: skip
                  player.toggle(sound) else { continue }            // a file that won't load: skip
            player.setVolume(volume, for: sound)
        }
    }

    func openPlayer() {
        coordinator.presentSleepPlayer()                   // → sheet = .sleepPlayer
    }

    func dismissMessage() { message = nil }

    /// Remembers the current mix (sound → volume) for "Play last mix" next night.
    private func saveMix() {
        guard hasMix else { return }                       // keep the last NON-empty mix
        settings.lastSleepMix = Dictionary(uniqueKeysWithValues: player.volumes.map { ($0.key.rawValue, $0.value) })
    }

    // MARK: - Bedtime reminder

    var reminderOn: Bool { settings.bedtimeReminderOn }

    /// The reminder time as a Date (for the time picker). Writing it reschedules the reminder.
    var bedtime: Date {
        get {
            let minutes = settings.bedtimeMinuteOfDay
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }
        set {
            settings.bedtimeMinuteOfDay = WakeStats.minuteOfDay(newValue)
            if settings.bedtimeReminderOn {
                Task { await scheduleReminder() }
            }
        }
    }

    /// ← CALLED BY: the reminder switch. Asks for notification permission the first time.
    ///
    /// WHY the request number (found in code review): switching ON shows the permission popup and
    /// WAITS. If the user switches OFF meanwhile, the old ON call would wake up later and turn the
    /// reminder back on. Only the newest tap is allowed to change anything after an `await`.
    func setReminder(_ isOn: Bool) async {
        reminderRequest += 1
        let request = reminderRequest
        guard isOn else {
            settings.bedtimeReminderOn = false
            reminder.cancel()
            return
        }
        let allowed = await reminder.requestPermission()   // → system popup (first time only)
        guard request == reminderRequest else { return }   // the user changed their mind meanwhile
        guard allowed else {
            settings.bedtimeReminderOn = false
            message = "Notifications are off for RiseUp. Turn them on in Settings → RiseUp → Notifications."
            return
        }
        settings.bedtimeReminderOn = true
        await scheduleReminder()
    }

    private func scheduleReminder() async {
        let minutes = settings.bedtimeMinuteOfDay
        do {
            try await reminder.schedule(hour: minutes / 60, minute: minutes % 60)
        } catch {
            settings.bedtimeReminderOn = false
            message = "Couldn't set the reminder. \(error.localizedDescription)"
        }
    }
}
