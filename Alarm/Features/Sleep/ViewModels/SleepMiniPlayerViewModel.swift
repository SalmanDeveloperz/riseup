//
//  SleepMiniPlayerViewModel.swift
//  RiseUp
//
//  LAYER: ViewModel (the sleep-sound mini player above the tab bar, #39)
//  WHAT:  "Rain + Ocean · stops in 23:41  ⏸ ✕", visible on EVERY tab while sleep sounds are on,
//         like Apple Music's mini player. Pause/play, stop, or tap to open the full mixer.
//  DATA:  none stored. Reads the long-lived SleepSoundPlayer (the single source of truth).
//
//  CONNECTIONS:
//    ← CREATED BY: ScreenFactory.makeSleepMiniPlayer() ← RootView (tab bar accessory)
//    → PLAYER:     SleepSoundPlaying.pause / resume / stopAll  (SleepSoundPlayer)
//    → OPENS:      AppCoordinator.presentSleepPlayer() → Now Playing sheet (Screen #20)
//
//  WHY (Salman's iPhone test): with sounds playing, nothing outside the Sleep tab showed it; to stop
//  them you had to find the Sleep tab first. Now the control is wherever you are.
//

import Foundation
import Observation

@Observable
final class SleepMiniPlayerViewModel {
    private let player: any SleepSoundPlaying
    private let coordinator: AppCoordinator

    init(player: any SleepSoundPlaying, coordinator: AppCoordinator) {
        self.player = player
        self.coordinator = coordinator
    }

    /// Should the mini player be on screen? Sounds are on (playing OR paused), and we're not on the
    /// Sleep tab, which has its own, bigger "now playing" card.
    /// ← USED BY: RootView (`tabViewBottomAccessory(isEnabled:)`) and tests
    static func isVisible(activeSounds: [SleepSound], selectedTab: AppTab) -> Bool {
        !activeSounds.isEmpty && selectedTab != .sleep
    }

    // MARK: - What it shows

    var isPlaying: Bool { player.isPlaying }

    /// "Rain", "Rain + Ocean", or "Rain + 2 more" (three or more would not fit the bar).
    var title: String {
        let titles = player.activeSounds.map(\.title)
        guard titles.count > 2 else { return titles.joined(separator: " + ") }
        return "\(titles[0]) + \(titles.count - 1) more"
    }

    /// The first sound's icon (the bar is small; one icon reads better than a row of them).
    var systemImage: String { player.activeSounds.first?.systemImage ?? "waveform" }

    /// When the sleep timer stops everything, if one is set. (The View counts down to it.)
    var timerEndsAt: Date? { player.timerEndsAt }

    // MARK: - Actions

    /// ← CALLED BY: the play/pause button
    func togglePause() {
        player.isPaused ? player.resume() : player.pause()
    }

    /// ← CALLED BY: the ✕ button. Everything stops; the bar disappears by itself (no sounds left).
    func stop() {
        Trace.log(.audio, "SleepMiniPlayerViewModel.stop() → SleepSoundPlayer.stopAll from the tab bar")
        player.stopAll()
    }

    /// ← CALLED BY: tapping the bar → the full mixer (volumes, sleep timer)
    func open() {
        coordinator.presentSleepPlayer()                 // → sheet = .sleepPlayer
    }
}
