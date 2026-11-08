//
//  Wallpaper.swift
//  RiseUp
//
//  LAYER: Model (plain value types, the wallpaper catalog)
//  WHAT:  What can be behind the Ringing screen:
//           • a LIVE wallpaper (animated, drawn by RiseUp in real time: aurora, synthwave…)
//           • one of the user's own PHOTOS (slow cinematic zoom)
//           • "Surprise me": a different live wallpaper every morning
//  DATA:  `WakeAlarm.wallpaperID` stores `Wallpaper.rawValue` (nil = the default from Settings).
//
//  CONNECTIONS:
//    ← USED BY: WallpaperView (draws it), WallpaperPickerViewModel (catalog), AlarmEditorViewModel,
//               RingingViewModel, AppSettings.defaultWallpaper
//
//  WHY live wallpapers are CODE, not videos: they load instantly (nothing to decode), stay sharp
//  on every screen size, can react to the alarm (they get more energetic the longer it rings),
//  and add almost nothing to the app's download size.
//
//  WHY raw values are written out ("live.aurora"): they're saved in the database. Renaming a
//  Swift case is fine; NEVER change a raw value after release (saved alarms would lose it).
//

import Foundation

/// What the Wallpaper Picker hands back: the wallpaper (nil = "Default"), and optionally the
/// scene's sound when the user tapped "Use wallpaper + sound" (nil = keep the current sound).
nonisolated struct WallpaperChoice: Equatable, Sendable {   //Equatable returns boolean value whether two values are equal or not
    var wallpaper: Wallpaper?
    var sound: AlarmSound?
}

/// Everything that can be an alarm's wallpaper.
nonisolated enum Wallpaper: Hashable, Sendable, Identifiable {
    case live(LiveWallpaper)
    /// A photo the user added. `id` names the file in WallpaperStore.
    case photo(id: UUID)
    /// A different live wallpaper each day (chosen by the date, so it's stable all morning).
    case surprise

    /// The default for new installs. TRY: change it to `.live(.synthwave)`.
    static let standard = Wallpaper.live(.goldenHour)

    var id: String { rawValue }

    /// What's stored: "live.aurora", "photo.<uuid>", "surprise".
    var rawValue: String {
        switch self {
        case .live(let live): "live.\(live.rawValue)"
        case .photo(let id): "photo.\(id.uuidString)"
        case .surprise: "surprise"
        }
    }

    /// Stored text → Wallpaper. Unknown text (e.g. a removed wallpaper) → nil.
    init?(rawValue: String) {
        if rawValue == "surprise" {
            self = .surprise
        } else if rawValue.hasPrefix("live."), let live = LiveWallpaper(rawValue: String(rawValue.dropFirst(5))) {
            self = .live(live)
        } else if rawValue.hasPrefix("photo."), let id = UUID(uuidString: String(rawValue.dropFirst(6))) {
            self = .photo(id: id)
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .live(let live): live.title
        case .photo: "My photo"
        case .surprise: "Surprise me"
        }
    }

    /// "Surprise me" → today's live wallpaper. Everything else stays as it is.
    /// LEARN: using the day number (not `random()`) means the choice is the same every time
    /// the screen opens that day, and changes tomorrow.
    func resolved(on date: Date = .now, calendar: Calendar = .current) -> Wallpaper {
        guard self == .surprise else { return self }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let all = LiveWallpaper.allCases
        return .live(all[day % all.count])
    }
}

/// The animated wallpapers RiseUp draws itself, grouped by mood.
/// ← DRAWN BY: the renderers in Features/Wallpapers/Renderers/
nonisolated enum LiveWallpaper: String, CaseIterable, Identifiable, Sendable {
    // Sunrise
    case goldenHour, aurora, dawnDrift
    // Nature
    case ocean, fireflies, rainyWindow
    // Space
    case hyperspace, nebula, planetRise
    // Neon energy
    case synthwave, neonPulse, lavaLamp
    // Calm
    case breathe, bokeh
    // Around the world (added 2026-10-13, round 2)
    case kyotoBlossoms, tajDawn, saharaDunes, savannaSunset, tropicalIsland, himalaya,
         parisNights, alpineMeadow, scottishHighlands, andesCondor, cityLights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goldenHour: "Golden Hour"
        case .aurora: "Aurora"
        case .dawnDrift: "Dawn Drift"
        case .ocean: "Ocean Waves"
        case .fireflies: "Firefly Forest"
        case .rainyWindow: "Rainy Window"
        case .hyperspace: "Hyperspace"
        case .nebula: "Nebula"
        case .planetRise: "Planet Rise"
        case .synthwave: "Synthwave"
        case .neonPulse: "Neon Pulse"
        case .lavaLamp: "Lava Lamp"
        case .breathe: "Breathe"
        case .bokeh: "Bokeh Lights"
        case .kyotoBlossoms: "Kyoto Blossoms"
        case .tajDawn: "Taj at Dawn"
        case .saharaDunes: "Sahara Dunes"
        case .savannaSunset: "Savanna Sunset"
        case .tropicalIsland: "Tropical Island"
        case .himalaya: "Himalaya"
        case .parisNights: "Paris Nights"
        case .alpineMeadow: "Alpine Meadow"
        case .scottishHighlands: "Scottish Highlands"
        case .andesCondor: "Andes Condor"
        case .cityLights: "City Lights"
        }
    }

    var category: WallpaperCategory {
        switch self {
        case .goldenHour, .aurora, .dawnDrift: .sunrise
        case .ocean, .fireflies, .rainyWindow: .nature
        case .hyperspace, .nebula, .planetRise: .space
        case .synthwave, .neonPulse, .lavaLamp: .energy
        case .breathe, .bokeh: .calm
        case .kyotoBlossoms, .tajDawn, .saharaDunes, .savannaSunset, .tropicalIsland, .himalaya,
             .parisNights, .alpineMeadow, .scottishHighlands, .andesCondor, .cityLights: .world
        }
    }

    /// The sound that belongs to this scene. It plays with the wallpaper in the picker's player,
    /// and "Use wallpaper + sound" sets it as the alarm's sound.
    /// TRY: give Hyperspace the `.siren` instead.
    var signatureSound: AlarmSound {
        switch self {
        case .goldenHour: .sunrise
        case .aurora: .harp
        case .dawnDrift: .kalimba
        case .ocean: .seashore
        case .fireflies: .rainforest
        case .rainyWindow: .lofi
        case .hyperspace: .electro
        case .nebula: .starlight
        case .planetRise: .epicStrings
        case .synthwave: .arcade
        case .neonPulse: .pulse
        case .lavaLamp: .marimba
        case .breathe: .singingBowls
        case .bokeh: .acousticGuitar
        case .kyotoBlossoms: .koto
        case .tajDawn: .sitar
        case .saharaDunes: .desertOud
        case .savannaSunset: .savannaDrums
        case .tropicalIsland: .steelDrum
        case .himalaya: .singingBowls
        case .parisNights: .accordion
        case .alpineMeadow: .alpineHorn
        case .scottishHighlands: .highlandPipes
        case .andesCondor: .panFlute
        case .cityLights: .jazzPiano
        }
    }
}

/// Picker tabs, in display order.
nonisolated enum WallpaperCategory: String, CaseIterable, Identifiable, Sendable {
    case saved, world, sunrise, nature, space, energy, calm, myPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: "Saved"
        case .world: "Around the World"
        case .sunrise: "Sunrise"
        case .nature: "Nature"
        case .space: "Space"
        case .energy: "Neon Energy"
        case .calm: "Calm"
        case .myPhotos: "My Photos"
        }
    }

    var systemImage: String {
        switch self {
        case .saved: "heart.fill"
        case .world: "globe.americas.fill"
        case .sunrise: "sunrise.fill"
        case .nature: "leaf.fill"
        case .space: "sparkles"
        case .energy: "bolt.fill"
        case .calm: "wind"
        case .myPhotos: "photo.on.rectangle.angled"
        }
    }

    /// The live wallpapers in this tab (empty for Saved and My Photos, which the ViewModel fills).
    var liveWallpapers: [LiveWallpaper] {
        LiveWallpaper.allCases.filter { $0.category == self }
    }
}

/// How "awake" a live wallpaper looks: a fixed level, or a ramp that rises while the alarm rings.
/// ← USED BY: LiveWallpaperView / PhotoWallpaperView (via WallpaperView), RingingView
nonisolated enum WallpaperEnergy: Equatable, Sendable {
    /// Always the same level, 0…1 (thumbnails, previews).
    case fixed(Double)
    /// Calm at `start`, fully awake after `duration` seconds. TRY: a shorter duration in RingingView.
    case ramp(start: Date, duration: TimeInterval)

    /// 0…1 at a given moment.
    func level(at date: Date) -> Double {
        switch self {
        case .fixed(let level):
            return min(1, max(0, level))
        case .ramp(let start, let duration):
            guard duration > 0 else { return 1 }
            return min(1, max(0, date.timeIntervalSince(start) / duration))
        }
    }

    /// The wallpaper's animation clock after `elapsed` real seconds.
    ///
    /// LEARN: the animation speed is `1 + boost × energy`. The clock is the AREA under that speed
    /// curve over time (an integral, like distance = area under a speed graph). For a straight-line
    /// ramp the area has a simple formula, so the animation speeds up smoothly and never jumps.
    ///   during the ramp:  e + boost·e² / (2·duration)
    ///   after the ramp:   duration + boost·duration/2 + (1 + boost)·(e − duration)
    func clock(elapsed e: TimeInterval, boost: Double) -> Double {
        switch self {
        case .fixed(let level):
            return e * (1 + boost * min(1, max(0, level)))
        case .ramp(_, let duration):
            guard duration > 0 else { return e * (1 + boost) }
            if e <= duration { return e + boost * e * e / (2 * duration) }
            return duration + boost * duration / 2 + (1 + boost) * (e - duration)
        }
    }
}

extension LiveWallpaper {
    /// How much faster this wallpaper moves at full energy (1 = twice as fast).
    /// Calm wallpapers barely speed up; Hyperspace goes to warp speed.
    var speedBoost: Double {
        switch self {
        case .hyperspace: 4
        case .synthwave: 2.5
        case .neonPulse, .lavaLamp: 1.5
        case .ocean, .rainyWindow, .aurora, .fireflies: 1.2
        case .goldenHour, .dawnDrift, .nebula, .planetRise: 0.8
        case .breathe, .bokeh: 0.4
        case .cityLights, .savannaSunset, .tropicalIsland: 1.2
        case .kyotoBlossoms, .tajDawn, .saharaDunes, .himalaya, .parisNights,
             .alpineMeadow, .scottishHighlands, .andesCondor: 0.8
        }
    }
}
