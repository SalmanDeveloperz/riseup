//
//  SleepSound.swift
//  RiseUp
//
//  LAYER: Model (plain value type)
//  WHAT:  The relaxing loops in the Sleep tab (Phase 6, Screen #19), grouped by mood.
//  DATA:  raw values are the file names in Alarm/Resources/SleepSounds (made by
//         Tools/generate_sleep_sounds.py). They're also SAVED as "last mix" in AppSettings.
//
//  CONNECTIONS:
//    ← USED BY: SleepSoundPlayer (loads the files), SleepViewModel / SleepPlayerViewModel (lists)
//
//  LEARN: never rename a raw value after release: a saved "last mix" would stop matching.
//

import Foundation

nonisolated enum SleepSound: String, CaseIterable, Identifiable, Sendable {
    case rain = "sleep_rain"
    case ocean = "sleep_ocean"
    case stream = "sleep_stream"
    case wind = "sleep_wind"
    case crickets = "sleep_crickets"
    case fire = "sleep_fire"
    case fan = "sleep_fan"
    case white = "sleep_white"
    case pink = "sleep_pink"
    case brown = "sleep_brown"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: "Rain"
        case .ocean: "Ocean"
        case .stream: "Stream"
        case .wind: "Wind"
        case .crickets: "Night"
        case .fire: "Fireplace"
        case .fan: "Fan"
        case .white: "White noise"
        case .pink: "Pink noise"
        case .brown: "Brown noise"
        }
    }

    var systemImage: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .ocean: "water.waves"
        case .stream: "drop.fill"
        case .wind: "wind"
        case .crickets: "moon.stars.fill"
        case .fire: "flame.fill"
        case .fan: "fan.fill"
        case .white: "waveform"
        case .pink: "waveform.path"
        case .brown: "waveform.path.ecg"
        }
    }

    var category: Category {
        switch self {
        case .rain, .ocean, .stream, .wind, .crickets: .nature
        case .fire, .fan: .cozy
        case .white, .pink, .brown: .noise
        }
    }

    /// The sections of the Sleep tab.
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case nature, cozy, noise
        var id: String { rawValue }

        var title: String {
            switch self {
            case .nature: "Nature"
            case .cozy: "Cozy"
            case .noise: "Noise"
            }
        }

        var sounds: [SleepSound] { SleepSound.allCases.filter { $0.category == self } }
    }
}
