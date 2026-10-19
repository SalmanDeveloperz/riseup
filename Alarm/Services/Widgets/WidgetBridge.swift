//
//  WidgetBridge.swift
//  RiseUp
//
//  LAYER: Service (app side of the home & lock screen widgets, Screen #31)
//  WHAT:  Hands the widgets what they need, ready to draw:
//           1. the next rings of every switched-on alarm (a week ahead) → WidgetSnapshot
//           2. a still picture of each of those alarms' wallpapers      → JPEG files
//         Then asks iOS to redraw the widgets, but only if something changed.
//  DATA:  reads WakeAlarm (AlarmRepository.alarms), AppSettings.defaultWallpaper, wallpaper
//         photos (WallpaperStore). Writes the App Group (Shared/WidgetSnapshot.swift).
//
//  CONNECTIONS:
//    ← CALLED BY: RootView, after every sync (launch + foreground) and when RiseUp goes to the background
//    → WRITES:    WidgetSnapshot.save() + picture files in WidgetShared.wallpaperFolder
//    → RELOADS:   WidgetCenter.reloadTimelines(ofKind:) → iOS runs RiseUpWidgets/NextAlarmWidget
//
//  WHY pictures and not the live wallpaper: a widget is a SNAPSHOT. iOS draws it once and shows
//  that image; it can't run 60 frames a second (that's what the Ringing screen is for). So we
//  freeze each wallpaper at a beautiful moment and the widget shows that frame.
//
//  WHY a stateless `enum` (no instance in AppDependencies): it keeps nothing between calls.
//  Everything it needs comes in as arguments, and its "memory" is the files it wrote.
//

import SwiftUI
import UIKit
import WidgetKit

enum WidgetBridge {

    /// How far ahead the widgets know your alarms. They move to the next ring by themselves,
    /// even if RiseUp isn't opened for days. TRY: 3 to see the list get shorter.
    static let daysAhead = 8
    /// At most this many rings (a widget shows 4 at most; the rest is for moving on).
    static let maxEvents = 24
    /// Picture size in points (×2 pixels): as big as the large widget on the biggest iPhone.
    static let pictureSize = CGSize(width: 364, height: 382)

    // MARK: - Update

    /// Writes the snapshot + pictures and reloads the widgets if anything changed.
    ///
    /// LEARN: `@MainActor` because ImageRenderer (SwiftUI → picture) only works on the main thread.
    /// Each picture is drawn ONCE (the file is kept), so this is quick after the first time.
    @MainActor
    static func update(alarms: [WakeAlarm], settings: AppSettings, wallpaperStore: any WallpaperStoring,
                       customSounds: any CustomSoundStoring, now: Date = .now) async {
        // No App Group (e.g. not set up for this Apple Account yet): nothing to share with.
        guard let folder = WidgetShared.wallpaperFolder else { return }

        let planned = plan(alarms: alarms, defaultWallpaper: settings.defaultWallpaper, now: now,
                           soundTitle: { customSounds.choice(for: $0).title })   // "Radar", or the user's own name

        // 1. Pictures first: the widget may redraw the moment the snapshot changes.
        var drewNewPicture = false
        var neededFiles: Set<String> = []
        for (event, wallpaper) in planned {
            guard let file = event.wallpaperFile, !neededFiles.contains(file) else { continue }
            neededFiles.insert(file)
            let url = folder.appending(path: file)
            if FileManager.default.fileExists(atPath: url.path()) { continue }
            if let picture = await still(of: wallpaper, store: wallpaperStore),
               let jpeg = picture.jpegData(compressionQuality: 0.82) {
                try? jpeg.write(to: url, options: .atomic)
                drewNewPicture = true
            }
        }
        removeUnusedPictures(in: folder, keeping: neededFiles)

        // 2. The list. `save()` says whether it differs from what the widgets have.
        let snapshot = WidgetSnapshot(upcoming: planned.map(\.event), writtenAt: now)
        let changed = snapshot.save()
        Trace.log(.widget, "WidgetBridge.update → \(planned.count) rings, \(neededFiles.count) pictures, changed: \(changed || drewNewPicture)")
        if changed || drewNewPicture {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.nextAlarmKind)   // → NextAlarmWidget
        }
    }

    /// Redraws the widgets in the new colours after the palette changed (#35).
    /// ← CALLED BY: SettingsViewModel.palette
    static func reloadForNewTheme() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.nextAlarmKind)
    }

    // MARK: - Planning (pure: no files, easy to test)

    /// Every ring of every switched-on alarm in the next `daysAhead` days, earliest first,
    /// with the wallpaper it will show (its own, or the Settings default; "Surprise" resolved per day).
    ///
    /// ← USED BY: update(), WidgetTests
    /// `soundTitle`: a stored sound name → what the widget shows (the user's own sounds have their own names).
    static func plan(alarms: [WakeAlarm], defaultWallpaper: Wallpaper, now: Date,
                     calendar: Calendar = .current,
                     soundTitle: (String) -> String = { AlarmSound.from($0).title })
        -> [(event: WidgetAlarmEvent, wallpaper: Wallpaper)] {
        let horizon = now.addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600)
        var result: [(event: WidgetAlarmEvent, wallpaper: Wallpaper)] = []

        for alarm in alarms where alarm.isEnabled {
            // One-time and quick alarms ring once; repeating ones on each chosen day.
            var date = now
            let maxRings = alarm.isRepeating ? 7 * daysAhead : 1
            for _ in 0..<maxRings {
                guard let next = alarm.nextFireDate(after: date), next <= horizon else { break }
                date = next
                let chosen = alarm.wallpaperID.flatMap(Wallpaper.init(rawValue:)) ?? defaultWallpaper
                let wallpaper = chosen.resolved(on: next, calendar: calendar)
                let event = WidgetAlarmEvent(
                    alarmID: alarm.id,
                    fireDate: next,
                    title: alarm.displayTitle,
                    missionSymbols: alarm.sortedMissions.map(\.type.systemImage),
                    soundTitle: soundTitle(alarm.soundName),
                    wallpaperTitle: wallpaper.title,
                    wallpaperFile: WidgetShared.wallpaperFileName(for: wallpaper.rawValue)
                )
                result.append((event, wallpaper))
            }
        }
        result.sort { $0.event.fireDate < $1.event.fireDate }
        return Array(result.prefix(maxEvents))
    }

    // MARK: - Pictures

    /// A still frame of a wallpaper, `pictureSize` at 2× (or a shrunk copy of the user's photo).
    @MainActor
    private static func still(of wallpaper: Wallpaper, store: any WallpaperStoring) async -> UIImage? {
        switch wallpaper {
        case .live(let style):
            // LEARN: ImageRenderer turns any SwiftUI view into a picture, off screen.
            let renderer = ImageRenderer(content: WallpaperStill(style: style)
                .frame(width: pictureSize.width, height: pictureSize.height))
            renderer.scale = 2
            return renderer.uiImage
        case .photo(let id):
            guard let photo = await store.image(for: id) else { return nil }
            // Shrink, keeping its shape, so the long side fits the picture (widgets have little memory).
            let target = pictureSize.height * 2
            let factor = min(1, target / max(photo.size.width, photo.size.height))
            let size = CGSize(width: photo.size.width * factor, height: photo.size.height * factor)
            return await photo.byPreparingThumbnail(ofSize: size)
        case .surprise:
            return nil                              // never here: `plan` resolves Surprise first
        }
    }

    /// Deletes pictures no upcoming ring uses any more (keeps the shared folder small).
    private static func removeUnusedPictures(in folder: URL, keeping: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path())) ?? []
        for file in files where !keeping.contains(file) {
            try? FileManager.default.removeItem(at: folder.appending(path: file))
        }
    }
}

/// One frozen frame of a live wallpaper, drawn by the same renderer as the Ringing screen.
/// WHY time 12 and energy 0.55: a few seconds in, things are spread out and lit up nicely,
/// but not yet at the wild "wide awake" level. TRY: energy 1 for brighter widgets.
struct WallpaperStill: View {
    let style: LiveWallpaper

    var body: some View {
        let time = Double(LiveWallpaper.allCases.firstIndex(of: style) ?? 0) * 37 + 12
        if style == .breathe {
            BreatheWallpaper(time: time, energy: 0.55)
        } else {
            Canvas { context, size in
                LiveWallpaperView.draw(style, context: &context, size: size, time: time, energy: 0.55)
            }
        }
    }
}
