//
//  CustomSound.swift
//  RiseUp
//
//  LAYER: Model (plain value types, no database)
//  WHAT:  • CustomSound: a sound the USER added (from Files, or the sound of a video in Photos).
//         • SoundChoice: "which sound does this alarm play?", one of ours OR one of theirs.
//  DATA:  `WakeAlarm.soundName` stores `SoundChoice.soundName`:
//           one of ours   → "riseup_radar.caf"                 (a file in the app)
//           one of yours  → "riseup_custom_<UUID>.caf"          (a file in Library/Sounds)
//
//  CONNECTIONS:
//    ← MADE BY:   CustomSoundLibrary (import, rename, list) → `choice(for:)` turns a stored name into a SoundChoice
//    ← USED BY:   SoundPickerViewModel, AlarmDraft, AudioService (what to play), AlarmKitScheduler (file check),
//                 WallpaperPickerViewModel, RingingViewModel, WidgetBridge (titles)
//
//  WHY the stored value is still a FILE NAME (same rule as AlarmSound): AlarmKit plays a sound by
//  file name, so `soundName` goes straight to iOS. No database change was needed for custom sounds.
//

import Foundation

/// A sound the user added. Its audio lives in `Library/Sounds/<fileName>`; this is the label.
nonisolated struct CustomSound: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    /// What the user sees ("Morning song"). The user's own words: never logged.
    var name: String
    /// Length of the saved clip in seconds (at most `SoundClipMaker.maxClipSeconds`).
    let duration: Double
    let createdAt: Date

    /// Every custom sound file starts with this, so we can tell them from ours at a glance.
    /// Never change it: saved alarms store names that start with it.
    static let filePrefix = "riseup_custom_"

    /// "riseup_custom_3F2A….caf": the name iOS and `WakeAlarm.soundName` use.
    var fileName: String { Self.fileName(for: id) }

    static func fileName(for id: UUID) -> String { "\(filePrefix)\(id.uuidString).caf" }

    /// The id inside a custom file name, or nil if `soundName` isn't a custom sound.
    static func id(fromFileName soundName: String) -> UUID? {
        guard soundName.hasPrefix(filePrefix), soundName.hasSuffix(".caf") else { return nil }
        return UUID(uuidString: String(soundName.dropFirst(filePrefix.count).dropLast(4)))
    }

    /// "0:28" for the row's subtitle.
    var durationText: String {
        let seconds = Int(duration.rounded())
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

/// The sound an alarm plays.
///
/// LEARN: an enum with "associated values" holds a different kind of value per case: here an
/// `AlarmSound` (our catalog) OR a `CustomSound` (the user's file). A `switch` must handle both,
/// so the compiler reminds us everywhere a custom sound needs different treatment.
nonisolated enum SoundChoice: Hashable, Identifiable, Sendable {
    case builtIn(AlarmSound)
    case custom(CustomSound)

    var id: String { soundName }

    /// What `WakeAlarm.soundName` stores, and the file name AlarmKit gets.
    var soundName: String {
        switch self {
        case .builtIn(let sound): sound.rawValue
        case .custom(let sound): sound.fileName
        }
    }

    var title: String {
        switch self {
        case .builtIn(let sound): sound.title
        case .custom(let sound): sound.name
        }
    }

    var subtitle: String {
        switch self {
        case .builtIn(let sound): sound.subtitle
        case .custom(let sound): "Your sound · \(sound.durationText)"
        }
    }

    var systemImage: String {
        switch self {
        case .builtIn(let sound): sound.systemImage
        case .custom: "waveform"
        }
    }

    /// The built-in sound, if this is one (Settings' default sound only takes those).
    var builtIn: AlarmSound? {
        if case .builtIn(let sound) = self { sound } else { nil }
    }
}

/// Which sound iOS really gets for an alarm. Pure, so tests can check it without AlarmKit.
/// ← USED BY: AlarmKitScheduler.sound(named:)
nonisolated enum AlarmSoundRule {
    /// True → use iOS's own alarm sound. For "default", and for a custom sound whose file is gone.
    /// `fileExists` is passed in so tests can pretend a file exists or not.
    static func usesSystemSound(_ soundName: String, fileExists: (String) -> Bool) -> Bool {
        if soundName == AlarmSound.systemDefault.rawValue { return true }
        guard CustomSound.id(fromFileName: soundName) != nil else { return false }   // one of ours: in the app
        let path = CustomSoundLibrary.soundsFolder.appendingPathComponent(soundName).path
        return !fileExists(path)
    }
}
