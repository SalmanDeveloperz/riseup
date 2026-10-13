//
//  AlarmSound.swift
//  RiseUp
//
//  LAYER: Model (plain value type, the sound catalog)
//  WHAT:  Every alarm sound the user can pick: file name, display name, category, icon.
//  DATA:  `WakeAlarm.soundName` stores `AlarmSound.rawValue` (e.g. "riseup_radar.caf").
//
//  CONNECTIONS:
//    ← USED BY: SoundPickerViewModel (list), AlarmEditorView (row title),
//               AudioService (finds the file to play), AlarmKitScheduler (sound for iOS)
//    ← FILES:   Alarm/Resources/Sounds/riseup_*.caf, made by Tools/generate_sounds.py
//
//  WHY raw values are FILE NAMES: AlarmKit plays a sound by file name, so the stored
//  string can go straight to iOS. Never rename a raw value after release; saved alarms
//  would lose their sound. (Renaming the Swift case is fine.)
//

import Foundation

nonisolated enum AlarmSound: String, CaseIterable, Identifiable, Sendable {
    case systemDefault = "default"
    case digital = "riseup_digital.caf"
    case radar = "riseup_radar.caf"
    case bell = "riseup_bell.caf"
    case siren = "riseup_siren.caf"
    case pulse = "riseup_pulse.caf"
    case arcade = "riseup_arcade.caf"
    case sunrise = "riseup_sunrise.caf"
    case marimba = "riseup_marimba.caf"
    // Added 2026-10-13 (richer instruments: bells, plucked strings, drums…).
    case twinBell = "riseup_twinbell.caf"
    case oldPhone = "riseup_oldphone.caf"
    case westminster = "riseup_westminster.caf"
    case electro = "riseup_electro.caf"
    case fanfare = "riseup_fanfare.caf"
    case schoolBell = "riseup_schoolbell.caf"
    case birds = "riseup_birds.caf"
    case harp = "riseup_harp.caf"
    case kalimba = "riseup_kalimba.caf"
    case lofi = "riseup_lofi.caf"
    case ocean = "riseup_ocean.caf"

    var id: String { rawValue }

    /// Name shown in the picker.
    var title: String {
        switch self {
        case .systemDefault: "iPhone Alarm"
        case .digital: "Digital"
        case .radar: "Radar"
        case .bell: "Bell"
        case .siren: "Siren"
        case .pulse: "Rapid Pulse"
        case .arcade: "Arcade"
        case .sunrise: "Sunrise"
        case .marimba: "Marimba"
        case .twinBell: "Twin Bell Clock"
        case .oldPhone: "Old Phone"
        case .westminster: "Westminster Chimes"
        case .electro: "Electro Beat"
        case .fanfare: "Fanfare"
        case .schoolBell: "School Bell"
        case .birds: "Morning Birds"
        case .harp: "Harp Rise"
        case .kalimba: "Kalimba"
        case .lofi: "Lo-fi Morning"
        case .ocean: "Ocean Sunrise"
        }
    }

    /// One-line description under the name.
    var subtitle: String {
        switch self {
        case .systemDefault: "The standard iOS alarm sound"
        case .digital: "Classic watch beeps"
        case .radar: "Bright, steady pings"
        case .bell: "Old-school ringing bell"
        case .siren: "Loud sweeping siren"
        case .pulse: "Urgent beeps that speed up"
        case .arcade: "Retro game melody"
        case .sunrise: "Gentle chimes that grow louder"
        case .marimba: "Soft wooden melody"
        case .twinBell: "The wind-up clock with two bells"
        case .oldPhone: "Classic telephone ring"
        case .westminster: "Big Ben's famous tune on church bells"
        case .electro: "Upbeat dance loop to get you moving"
        case .fanfare: "Bright brass: rise and shine!"
        case .schoolBell: "Loud electric bell, hard to ignore"
        case .birds: "Birdsong and a soft breeze"
        case .harp: "Rising harp chords, gently louder"
        case .kalimba: "Happy thumb-piano tune"
        case .lofi: "Mellow chords and a lazy beat"
        case .ocean: "Waves and chimes at dawn"
        }
    }

    var category: Category {
        switch self {
        case .systemDefault, .digital, .radar, .bell, .twinBell, .oldPhone, .westminster: .classic
        case .siren, .pulse, .arcade, .electro, .fanfare, .schoolBell: .loud
        case .sunrise, .marimba, .birds, .harp, .kalimba, .lofi, .ocean: .gentle
        }
    }

    var systemImage: String {
        switch self {
        case .systemDefault: "iphone"
        case .digital: "clock.fill"
        case .radar: "dot.radiowaves.left.and.right"
        case .bell: "bell.fill"
        case .siren: "light.beacon.max.fill"
        case .pulse: "waveform.path.ecg"
        case .arcade: "gamecontroller.fill"
        case .sunrise: "sunrise.fill"
        case .marimba: "music.note"
        case .twinBell: "alarm.fill"
        case .oldPhone: "phone.fill"
        case .westminster: "building.columns.fill"
        case .electro: "hifispeaker.fill"
        case .fanfare: "megaphone.fill"
        case .schoolBell: "bell.and.waves.left.and.right.fill"
        case .birds: "bird.fill"
        case .harp: "music.quarternote.3"
        case .kalimba: "music.note.list"
        case .lofi: "headphones"
        case .ocean: "water.waves"
        }
    }

    /// The file to play INSIDE RiseUp (previews, ringing screen).
    ///
    /// WHY "default" maps to Digital here: iOS's own alarm sound can't be played by apps;
    /// only iOS itself (AlarmKit) can. Inside the app we use our closest equivalent.
    var playableFileName: String {
        self == .systemDefault ? AlarmSound.digital.rawValue : rawValue
    }

    /// The sound for a stored `soundName`. Unknown names (e.g. old test files) fall back to default.
    static func from(_ soundName: String) -> AlarmSound {
        AlarmSound(rawValue: soundName) ?? .systemDefault
    }

    /// Groups in the picker, in display order.
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case classic = "Classic"
        case loud = "Loud & energetic"
        case gentle = "Gentle wake-up"

        var id: String { rawValue }

        var sounds: [AlarmSound] {
            AlarmSound.allCases.filter { $0.category == self }
        }
    }
}
