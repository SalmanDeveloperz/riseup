//
//  TimeAnnouncer.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  "Time Pressure": says the time out loud, e.g. "It's 6:32. Keep going!"
//         Used every minute while the user works on missions (the alarm sound is paused then).
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → SpeechTimeAnnouncer, preview → MockTimeAnnouncer)
//    ← USED BY:    RingingViewModel (if AppSettings.speaksTimeWhileRinging is on)
//    → USES:       AVFoundation's AVSpeechSynthesizer (the built-in iOS voice)
//
//  WHY: hearing the minutes tick by is a strong nudge to finish the mission instead of
//  drifting back to sleep halfway through.
//

import AVFoundation
import Foundation

protocol TimeAnnouncing: AnyObject {
    /// Speaks the time of `date` (and a short nudge).
    func announce(_ date: Date)
    /// Stops speaking immediately.
    func stop()
}

final class SpeechTimeAnnouncer: TimeAnnouncing {
    /// LEARN: the synthesizer must be STORED. A local `let` would be released at the end
    /// of the function, and the speech would stop after the first word.
    private let synthesizer = AVSpeechSynthesizer()

    /// TRY: add your own phrase, e.g. "Rise and shine!".
    private let nudges = ["Keep going!", "You've got this.", "Almost there.", "Time to get up!"]

    func announce(_ date: Date) {
        // `.formatted(date: .omitted, time: .shortened)` → "6:32 AM" or "06:32", the user's style.
        let time = date.formatted(date: .omitted, time: .shortened)
        let utterance = AVSpeechUtterance(string: "It's \(time). \(nudges.randomElement() ?? "")")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // WHY no language set: the system voice matches the phone's language automatically.
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

/// Silent fake for Previews and tests; remembers how often it was asked to speak.
final class MockTimeAnnouncer: TimeAnnouncing {
    private(set) var announcements = 0
    func announce(_ date: Date) { announcements += 1 }
    func stop() {}
}
