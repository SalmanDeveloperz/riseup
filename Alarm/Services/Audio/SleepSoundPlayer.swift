//
//  SleepSoundPlayer.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  The sleep-sound MIXER: plays up to 3 looping sounds at once, each with its own
//         volume, keeps playing when the phone is locked, stops after a sleep timer with a
//         gentle fade, and shows Play/Pause on the lock screen ("Now Playing").
//  DATA:  none stored here (the "last mix" is saved by SleepViewModel in AppSettings).
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → SleepSoundPlayer, preview → MockSleepSoundPlayer)
//    ← USED BY:    SleepViewModel (Screen #19), SleepPlayerViewModel (Screen #20),
//                  RingingViewModel (stops the mix when an alarm rings)
//    → USES:       AVFoundation (AVAudioSession, AVAudioPlayer), MediaPlayer (Now Playing)
//
//  WHY the service holds the state (and is @Observable): the music must keep playing after
//  the Sleep screen is closed, even with the phone locked. A ViewModel lives only as long as
//  its screen, so the mix (and the sleep timer) live HERE, in a long-lived service. Screens
//  just read it.
//
//  LEARN: background audio
//  ───────────────────────
//  iOS normally freezes an app soon after the screen locks. `UIBackgroundModes: audio` in
//  Config/Info.plist tells iOS "this app plays sound people listen to", so it keeps running
//  while audio plays. That's also why the sleep timer (a simple Task) keeps working in bed.
//

import AVFoundation
import Foundation
import MediaPlayer
import Observation

protocol SleepSoundPlaying: AnyObject {
    /// The sounds in the mix, in the order they were added.
    var activeSounds: [SleepSound] { get }
    /// 0…1 per active sound.
    var volumes: [SleepSound: Double] { get }
    var isPaused: Bool { get }
    /// When the sleep timer stops everything, or nil when no timer runs.
    var timerEndsAt: Date? { get }
    /// The length the timer was started with (for the countdown ring), or nil.
    var timerMinutes: Int? { get }

    /// Adds the sound to the mix (or removes it if it's already playing).
    /// Returns false if the mix is full (see `maxSounds`).
    @discardableResult func toggle(_ sound: SleepSound) -> Bool
    func setVolume(_ volume: Double, for sound: SleepSound)
    func pause()
    func resume()
    /// Stops every sound and the timer.
    func stopAll()
    /// Stops everything after `minutes`, fading out over the last 30 seconds.
    func startTimer(minutes: Int)
    func cancelTimer()
}

extension SleepSoundPlaying {
    var isPlaying: Bool { !activeSounds.isEmpty && !isPaused }
}

/// Mix limit. TRY: change to 4 and add four sounds.
nonisolated let sleepMixMaxSounds = 3

@Observable
final class SleepSoundPlayer: SleepSoundPlaying {
    private(set) var activeSounds: [SleepSound] = []
    private(set) var volumes: [SleepSound: Double] = [:]
    private(set) var isPaused = false
    private(set) var timerEndsAt: Date?
    private(set) var timerMinutes: Int?

    @ObservationIgnored private var players: [SleepSound: AVAudioPlayer] = [:]
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var remoteCommandsReady = false

    /// How long the volume takes to fade in/out when a sound starts/stops.
    private static let fade: TimeInterval = 1.2
    /// Fade-out at the end of the sleep timer. TRY: 60 for an even softer ending.
    private static let timerFade: TimeInterval = 30

    init() {
        // WHY: a phone call or an alarm interrupts our audio. iOS tells us through this
        // notification; we mark the mix as paused so the Play button is honest afterwards.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            // LEARN: `queue: .main` → this runs on the main thread; assumeIsolated tells Swift so.
            MainActor.assumeIsolated {
                if began { self?.isPaused = true; self?.updateNowPlaying() }
            }
        }
    }

    // MARK: - Mix

    @discardableResult
    func toggle(_ sound: SleepSound) -> Bool {
        if players[sound] != nil {
            remove(sound)
            return true
        }
        guard activeSounds.count < sleepMixMaxSounds else { return false }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        activateSession()
        player.numberOfLoops = -1                       // -1 = loop forever
        player.volume = 0
        player.play()
        let volume = 0.7
        player.setVolume(Float(volume), fadeDuration: Self.fade)   // fade in, no sudden noise
        players[sound] = player
        volumes[sound] = volume
        activeSounds.append(sound)
        if isPaused { resume() }                        // adding a sound means "play"
        updateNowPlaying()
        return true
    }

    func setVolume(_ volume: Double, for sound: SleepSound) {
        guard let player = players[sound] else { return }       // not in the mix: nothing to change
        let clamped = min(1, max(0, volume))
        volumes[sound] = clamped
        // WHY a tiny fade instead of `player.volume = …` (found in code review): a running fade
        // (fade-in, or the timer's fade-out) would keep going and overwrite a plain assignment.
        // A new fade REPLACES the old one.
        player.setVolume(Float(clamped), fadeDuration: 0.1)
    }

    func pause() {
        players.values.forEach { $0.pause() }
        isPaused = true
        updateNowPlaying()
    }

    func resume() {
        guard !players.isEmpty else { return }
        // WHY (found in code review): if the timer's end passed while the app was asleep, its Task
        // would wake up now and stop the mix the user just resumed. That timer is over: drop it.
        if let end = timerEndsAt, end <= .now { cancelTimer() }
        activateSession()
        players.values.forEach { $0.play() }
        isPaused = false
        updateNowPlaying()
    }

    func stopAll() {
        cancelTimer()
        players.values.forEach { $0.stop() }
        players = [:]
        volumes = [:]
        activeSounds = []
        isPaused = false
        updateNowPlaying()
        // Hand the speaker back: a podcast that was paused by our sounds may continue now.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func remove(_ sound: SleepSound) {
        if let player = players[sound] {
            player.setVolume(0, fadeDuration: Self.fade)
            // Stop after the fade. (The player is kept alive by this closure until then.)
            Task {
                try? await Task.sleep(for: .seconds(Self.fade))
                player.stop()
            }
        }
        players[sound] = nil
        volumes[sound] = nil
        activeSounds.removeAll { $0 == sound }
        if activeSounds.isEmpty { cancelTimer() }
        updateNowPlaying()
    }

    // MARK: - Sleep timer

    func startTimer(minutes: Int) {
        cancelTimer()
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        timerEndsAt = end
        timerMinutes = minutes
        timerTask = Task { [weak self] in
            // 1. Wait until 30 s before the end.
            let fadeStart = end.addingTimeInterval(-Self.timerFade)
            try? await Task.sleep(for: .seconds(max(0, fadeStart.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            // 2. Fade every sound to silence…
            self.players.values.forEach { $0.setVolume(0, fadeDuration: Self.timerFade) }
            try? await Task.sleep(for: .seconds(Self.timerFade))
            guard !Task.isCancelled else { return }
            // 3. …and stop. Good night.
            self.timerTask = nil
            self.stopAll()
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerEndsAt = nil
        timerMinutes = nil
        // If the fade had begun, put the volumes back (a short fade replaces the running one).
        for (sound, player) in players {
            player.setVolume(Float(volumes[sound] ?? 0.7), fadeDuration: 0.1)
        }
    }

    // MARK: - Audio session & lock screen

    private func activateSession() {
        // `.playback` = keeps playing in Silent mode and with the screen locked.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        setUpRemoteCommandsOnce()
    }

    /// Lock screen / Control Center title: "Rain + Fireplace".
    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard !activeSounds.isEmpty else {
            center.nowPlayingInfo = nil
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: activeSounds.map(\.title).joined(separator: " + "),
            MPMediaItemPropertyArtist: "RiseUp Sleep",
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0,
        ]
    }

    /// Play / Pause buttons on the lock screen and in Control Center.
    ///
    /// LEARN: the handler closures are `@Sendable`, because iOS may call them from any thread.
    /// We hop to the main actor with `Task { @MainActor in … }` before touching our state.
    /// (`self` may be captured: a main-actor class is automatically Sendable.)
    private func setUpRemoteCommandsOnce() {
        guard !remoteCommandsReady else { return }
        remoteCommandsReady = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isPaused { self.resume() } else { self.pause() }
            }
            return .success
        }
    }
}

/// Silent fake for Previews and tests: remembers the mix but plays nothing.
@Observable
final class MockSleepSoundPlayer: SleepSoundPlaying {
    private(set) var activeSounds: [SleepSound] = []
    private(set) var volumes: [SleepSound: Double] = [:]
    private(set) var isPaused = false
    private(set) var timerEndsAt: Date?
    private(set) var timerMinutes: Int?

    @discardableResult
    func toggle(_ sound: SleepSound) -> Bool {
        if activeSounds.contains(sound) {
            activeSounds.removeAll { $0 == sound }
            volumes[sound] = nil
            return true
        }
        guard activeSounds.count < sleepMixMaxSounds else { return false }
        activeSounds.append(sound)
        volumes[sound] = 0.7
        return true
    }
    func setVolume(_ volume: Double, for sound: SleepSound) {
        guard activeSounds.contains(sound) else { return }
        volumes[sound] = volume
    }
    func pause() { isPaused = true }
    func resume() { isPaused = false }
    func stopAll() { activeSounds = []; volumes = [:]; isPaused = false; cancelTimer() }
    func startTimer(minutes: Int) {
        timerEndsAt = .now.addingTimeInterval(TimeInterval(minutes * 60))
        timerMinutes = minutes
    }
    func cancelTimer() { timerEndsAt = nil; timerMinutes = nil }
}
