//
//  SleepPlayerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (Screen #20 Now Playing sheet)
//  WHAT:  A volume slider per sound in the mix, a sleep timer (15–90 min) with a live
//         countdown, Pause/Play and Stop.
//  DATA:  reads/writes the live mix in SleepSoundPlayer; saves the new volumes as the
//         "last mix" in AppSettings.
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeScreen(for: .sleepPlayer)
//    → AUDIO:      SleepSoundPlaying.setVolume / startTimer / cancelTimer / pause / resume / stopAll
//    → SETTINGS:   AppSettings.lastSleepMix
//    → NAVIGATES:  AppCoordinator.dismissSheet()
//
//  WHY no copy of the mix here: closing this sheet must NOT stop the music. The player
//  service owns the mix; this ViewModel only reads it and forwards taps.
//

import Foundation
import Observation

@Observable
final class SleepPlayerViewModel {
    private let player: any SleepSoundPlaying
    private let settings: AppSettings
    private let coordinator: AppCoordinator

    /// Sleep timer choices, in minutes. TRY: add 120 for a two-hour timer.
    let timerChoices = [15, 30, 45, 60, 90]

    init(player: any SleepSoundPlaying, settings: AppSettings, coordinator: AppCoordinator) {
        self.player = player
        self.settings = settings
        self.coordinator = coordinator
    }

    // MARK: - Reading the live mix

    var sounds: [SleepSound] { player.activeSounds }
    var hasMix: Bool { !player.activeSounds.isEmpty }
    var isPlaying: Bool { player.isPlaying }
    var timerEndsAt: Date? { player.timerEndsAt }

    func volume(of sound: SleepSound) -> Double { player.volumes[sound] ?? 0 }

    // MARK: - Actions

    /// ← CALLED BY: a volume slider (continuously while dragging)
    func setVolume(_ volume: Double, for sound: SleepSound) {
        player.setVolume(volume, for: sound)                // → AVAudioPlayer.volume
    }

    /// ← CALLED BY: the slider's "editing ended", so we save once, not 60 times a second.
    func saveVolumes() {
        guard hasMix else { return }
        settings.lastSleepMix = Dictionary(uniqueKeysWithValues: player.volumes.map { ($0.key.rawValue, $0.value) })
    }

    func remove(_ sound: SleepSound) {
        player.toggle(sound)                                // toggling a playing sound removes it
        saveVolumes()
        if !hasMix { close() }                              // nothing left to show
    }

    /// Which chip is highlighted. Read from the player, so it's right even after the sheet
    /// was closed and opened again, and it clears by itself when the timer ends.
    var activeTimerChoice: Int? { player.timerMinutes }

    /// Tapping the selected timer again turns it off.
    func chooseTimer(_ minutes: Int) {
        if activeTimerChoice == minutes {
            player.cancelTimer()
        } else {
            player.startTimer(minutes: minutes)             // → fade out over the last 30 s
        }
    }

    func togglePause() {
        if player.isPaused { player.resume() } else { player.pause() }
    }

    func stop() {
        player.stopAll()
        close()
    }

    func close() {
        coordinator.dismissSheet()                          // → sheet = nil (music keeps playing)
    }

    /// "12:34" left on the timer, for the countdown label.
    /// LEARN: `Duration.formatted(.time(pattern:))` turns seconds into a clock-style string.
    static func remainingText(until end: Date, now: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now).rounded()))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }
}
