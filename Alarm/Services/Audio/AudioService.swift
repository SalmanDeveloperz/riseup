//
//  AudioService.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  Plays sounds INSIDE RiseUp: short previews in the Sound Picker, and the looping
//         alarm sound on the Ringing screen (with a gentle volume ramp and a mute button).
//  DATA:  none. Reads sound files from the app bundle.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → AudioService, preview → MockAudioService)
//    ← USED BY:    SoundPickerViewModel (preview), RingingViewModel (alarm loop, mute)
//    → USES:       AVFoundation (AVAudioSession + AVAudioPlayer), AlarmSound (file names)
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
    func preview(_ sound: AlarmSound)
    /// Stops the preview, if any.
    func stopPreview()
    /// Starts looping an alarm sound. `rampUp` starts quiet and reaches full volume after ~15 s.
    func startAlarm(_ sound: AlarmSound, rampUp: Bool)
    /// Stops the alarm loop.
    func stopAlarm()
    /// Temporarily silences the alarm loop without stopping it.
    func setAlarmMuted(_ isMuted: Bool)
}

final class AudioService: AudioPlaying {
    private var previewPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var rampTask: Task<Void, Never>?
    private var isMuted = false

    /// Volume the ramp is currently at (mute → 0, unmute → back to this).
    private var currentVolume: Float = 1

    // MARK: - Preview

    func preview(_ sound: AlarmSound) {
        stopPreview()
        guard let player = makePlayer(for: sound) else { return }
        player.numberOfLoops = 0
        player.volume = 1
        activateSession()
        player.play()
        previewPlayer = player
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    // MARK: - Alarm loop

    func startAlarm(_ sound: AlarmSound, rampUp: Bool) {
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

    // MARK: - Helpers

    private func makePlayer(for sound: AlarmSound) -> AVAudioPlayer? {
        let name = sound.playableFileName
        // "riseup_radar.caf" → resource "riseup_radar", extension "caf"
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext) else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    /// WHY `.playback`: this category plays sound even when the iPhone's Silent switch is
    /// on. Exactly what an alarm needs. (The default category would be muted by Silent mode.)
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}

/// Fake audio for Previews and tests: remembers what it was asked to do, plays nothing.
final class MockAudioService: AudioPlaying {
    private(set) var previewedSound: AlarmSound?
    private(set) var alarmSound: AlarmSound?
    private(set) var isMuted = false

    func preview(_ sound: AlarmSound) { previewedSound = sound }
    func stopPreview() { previewedSound = nil }
    func startAlarm(_ sound: AlarmSound, rampUp: Bool) { alarmSound = sound }
    func stopAlarm() { alarmSound = nil }
    func setAlarmMuted(_ isMuted: Bool) { self.isMuted = isMuted }
}
