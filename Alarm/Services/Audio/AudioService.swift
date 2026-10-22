//
//  AudioService.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  Plays sounds INSIDE RiseUp: short previews in the Sound Picker, and the looping
//         alarm sound on the Ringing screen (with a gentle volume ramp and a mute button).
//  DATA:  none. Reads sound files from the app bundle, and the user's own from Library/Sounds.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → AudioService, preview → MockAudioService)
//    ← USED BY:    SoundPickerViewModel (preview), RingingViewModel (alarm loop, mute)
//    → USES:       AVFoundation (AVAudioSession + AVAudioPlayer), SoundChoice → AlarmSound / CustomSound files
//
//  LEARN: AlarmKit vs. this service
//  ────────────────────────────────
//  • AlarmKit rings when RiseUp is CLOSED: iOS plays the sound.
//  • This service plays when RiseUp is OPEN (picker previews, the mission screen after
//    "Start Mission" silenced the system alarm). Without it, the phone would go quiet
//    the moment the user opened the app, and they'd fall back asleep.
//

import AVFoundation
import Foundation

/// Everything the app needs from audio.
protocol AudioPlaying: AnyObject {
    /// Plays a sound once (stops any other preview first).
    func preview(_ sound: SoundChoice)
    /// Plays a sound over and over until `stopPreview()` (the wallpaper scene player).
    func previewLooping(_ sound: SoundChoice)
    /// Stops the preview, if any.
    func stopPreview()
    /// Starts looping an alarm sound. `rampUp` starts quiet and reaches full volume after ~15 s.
    func startAlarm(_ sound: SoundChoice, rampUp: Bool)
    /// Stops the alarm loop.
    func stopAlarm()
    /// Temporarily silences the alarm loop without stopping it.
    func setAlarmMuted(_ isMuted: Bool)
    /// The iPhone's media volume, 0…1 (the volume the app's own sounds play at).
    /// WHY: inside RiseUp the alarm plays at the MEDIA volume, not the ringer volume, and Apple
    /// doesn't let apps change it. The Ringing screen asks the user to turn it up when it's low.
    var outputVolume: Float { get }
}

final class AudioService: AudioPlaying {
    private var previewPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var rampTask: Task<Void, Never>?
    private var isMuted = false

    /// Volume the ramp is currently at (mute → 0, unmute → back to this).
    private var currentVolume: Float = 1
    private var interruptionObserver: NSObjectProtocol?

    init() {
        // WHY (found in the code review): a phone call during a mission pauses our alarm sound,
        // and nothing started it again afterwards, so the user could quietly fall back asleep.
        // When iOS says the interruption is over, the alarm continues.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.ended.rawValue
            // LEARN: `queue: .main` → this runs on the main thread; assumeIsolated tells Swift so.
            MainActor.assumeIsolated {
                guard ended, let self, let player = self.alarmPlayer, !player.isPlaying else { return }
                self.activateSession()
                player.play()
            }
        }
    }

    // MARK: - Preview

    func preview(_ sound: SoundChoice) {
        stopPreview()
        guard let player = makePlayer(for: sound) else { return }
        player.numberOfLoops = 0
        player.volume = 1
        activateSession()
        player.play()
        previewPlayer = player
    }

    func previewLooping(_ sound: SoundChoice) {
        preview(sound)
        // LEARN: -1 = loop forever. The 12-second sounds are made to loop without a gap.
        previewPlayer?.numberOfLoops = -1
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    // MARK: - Alarm loop

    func startAlarm(_ sound: SoundChoice, rampUp: Bool) {
        // (`soundName` is a file name, never the user's own words, so it's fine in the trace.)
        Trace.log(.audio, "AudioService.startAlarm(\(sound.soundName)) rampUp: \(rampUp)")
        stopAlarm()
        stopPreview()
        guard let player = makePlayer(for: sound) else { return }
        // LEARN: `numberOfLoops = -1` repeats forever until `stop()`.
        player.numberOfLoops = -1
        currentVolume = rampUp ? 0.25 : 1
        player.volume = isMuted ? 0 : currentVolume
        activateSession()
        player.play()
        alarmPlayer = player

        if rampUp {
            // Raise the volume a little every second: 0.25 → 1.0 over ~15 s.
            // LEARN: a `Task` with a loop + `Task.sleep` is the modern, simple way to
            // do "every second, until cancelled". `stopAlarm()` cancels it.
            rampTask = Task { [weak self] in
                for _ in 0..<15 {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    self.currentVolume = min(1, self.currentVolume + 0.05)
                    if !self.isMuted { self.alarmPlayer?.volume = self.currentVolume }
                }
            }
        }
    }

    func stopAlarm() {
        rampTask?.cancel()
        rampTask = nil
        alarmPlayer?.stop()
        alarmPlayer = nil
        isMuted = false
    }

    func setAlarmMuted(_ isMuted: Bool) {
        self.isMuted = isMuted
        // LEARN: `setVolume(_:fadeDuration:)` fades smoothly instead of cutting abruptly.
        alarmPlayer?.setVolume(isMuted ? 0 : currentVolume, fadeDuration: 0.3)
    }

    /// LEARN: `AVAudioSession.outputVolume` is the media volume the user set with the buttons.
    var outputVolume: Float { AVAudioSession.sharedInstance().outputVolume }

    // MARK: - Helpers

    private func makePlayer(for sound: SoundChoice) -> AVAudioPlayer? {
        guard let url = Self.fileURL(for: sound),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()          // loads the first audio now, so `play()` starts instantly
        return player
    }

    /// Where a sound's file is: inside the app (ours) or in Library/Sounds (the user's).
    /// WHY the fallback: if a custom sound's file is gone (deleted while an alarm still used it),
    /// the alarm must still make noise. The Digital beeps are our stand-in for "iPhone Alarm".
    nonisolated static func fileURL(for sound: SoundChoice) -> URL? {
        if case .custom(let custom) = sound {
            let url = CustomSoundLibrary.soundsFolder.appendingPathComponent(custom.fileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
            return bundleURL(for: .digital)
        }
        return sound.builtIn.flatMap(bundleURL(for:))
    }

    /// "riseup_radar.caf" → resource "riseup_radar", extension "caf" in the app.
    nonisolated private static func bundleURL(for sound: AlarmSound) -> URL? {
        let name = sound.playableFileName
        return Bundle.main.url(forResource: (name as NSString).deletingPathExtension,
                               withExtension: (name as NSString).pathExtension)
    }

    /// WHY `.playback`: this category plays sound even when the iPhone's Silent switch is
    /// on. Exactly what an alarm needs. (The default category would be muted by Silent mode.)
    ///
    /// WHY the category is set only once (found in the smoothness review): setting it on every
    /// tap made each sound preview start a little late.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback {
            try? session.setCategory(.playback, mode: .default)
        }
        try? session.setActive(true)
    }
}

/// Fake audio for Previews and tests: remembers what it was asked to do, plays nothing.
final class MockAudioService: AudioPlaying {
    private(set) var previewedSound: SoundChoice?
    private(set) var isPreviewLooping = false
    private(set) var alarmSound: SoundChoice?
    private(set) var isMuted = false

    func preview(_ sound: SoundChoice) { previewedSound = sound; isPreviewLooping = false }
    func previewLooping(_ sound: SoundChoice) { previewedSound = sound; isPreviewLooping = true }
    func stopPreview() { previewedSound = nil; isPreviewLooping = false }
    func startAlarm(_ sound: SoundChoice, rampUp: Bool) { alarmSound = sound }
    func stopAlarm() { alarmSound = nil }
    func setAlarmMuted(_ isMuted: Bool) { self.isMuted = isMuted }
    var outputVolume: Float = 1
}
