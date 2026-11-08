//
//  CustomSoundLibrary.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  The user's own alarm sounds: add (from Files or a video in Photos), list, rename, delete,
//         and "which sound is this stored name?" for the rest of the app.
//  DATA:  Library/Sounds/riseup_custom_<UUID>.caf    the clips (made by SoundClipMaker)
//         Library/Sounds/riseup_custom_sounds.json   their names, lengths and dates
//         NOT in the database: `WakeAlarm.soundName` only stores the file name.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → CustomSoundLibrary, previews → MockCustomSoundLibrary)
//    ← USED BY:    SoundPickerViewModel (add/rename/delete/list), AlarmEditorViewModel, RingingViewModel,
//                  WidgetBridge, SettingsViewModel (`choice(for:)`)
//    → CALLS:      SoundClipMaker.makeClip (background thread), FileManager, JSONEncoder
//
//  WHY Library/Sounds: AlarmKit finds a sound by its file name in two places only: inside the app
//  (read-only, fixed at build time) or in the app's Library/Sounds folder. A sound the user adds can
//  only go to the second one.
//  WHY the FILES are the truth and the JSON only adds names: if the JSON were ever lost or damaged,
//  every sound still works (it's just called "My sound" until renamed). Nothing an alarm needs is in it.
//
//  ⚠️ KNOWN iOS RISK (Apple Developer Forums, iOS 26.0, 2025–26): some developers report that AlarmKit
//  plays its DEFAULT alarm tone instead of a file from Library/Sounds. If that happens on an iPhone,
//  the alarm still rings (loudly, iOS's tone), and the user's own sound plays as soon as RiseUp opens
//  (Ringing screen, through AudioService). The alarm can never be silent because of a custom sound.
//

import Foundation
import Observation
import AVFoundation

/// What the app needs from the custom sound collection.
protocol CustomSoundStoring: AnyObject {
    /// The user's sounds, newest first. (Observable: the picker updates by itself.)
    var sounds: [CustomSound] { get }
    /// Turns `source` (an audio file or a video) into a new sound. Throws `SoundClipMaker.ImportError`.
    func add(from source: URL, suggestedName: String) async throws -> CustomSound
    /// Gives a sound a new name. Blank names are ignored.
    func rename(_ id: UUID, to name: String)
    /// Removes the sound and its file.
    func delete(_ id: UUID)
    /// The sound an alarm's stored `soundName` means.
    func choice(for soundName: String) -> SoundChoice
}

extension CustomSoundStoring {
    /// "Morning song" → "Morning song 2" if that name is taken (ignoring upper/lower case).
    func uniqueName(_ name: String, ignoring id: UUID? = nil) -> String {
        let taken = Set(sounds.filter { $0.id != id }.map { $0.name.lowercased() })
        guard taken.contains(name.lowercased()) else { return name }
        var number = 2
        while taken.contains("\(name) \(number)".lowercased()) { number += 1 }
        return "\(name) \(number)"
    }

    /// Shared by the real library and the mock, so both answer the same way.
    func resolve(_ soundName: String) -> SoundChoice {
        if let id = CustomSound.id(fromFileName: soundName) {
            // WHY "iPhone Alarm" for a sound that was deleted: it's what iOS will really play
            // (AlarmKitScheduler.sound(named:) checks the file), so the app says the truth.
            guard let sound = sounds.first(where: { $0.id == id }) else { return .builtIn(.systemDefault) }
            return .custom(sound)
        }
        return .builtIn(AlarmSound.from(soundName))
    }
}

@Observable
final class CustomSoundLibrary: CustomSoundStoring {
    /// TRY: change 50 to 3, run the app and add a 4th sound to see the "too many" message.
    nonisolated static let maxSounds = 50
    nonisolated static let maxNameLength = 40
    nonisolated static let manifestName = "riseup_custom_sounds.json"

    /// The folder AlarmKit searches: <app>/Library/Sounds.
    /// ← ALSO READ BY: AudioService (to play a custom sound) and AlarmKitScheduler (does the file exist?)
    nonisolated static var soundsFolder: URL {
        URL.libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
    }

    private(set) var sounds: [CustomSound] = []
    @ObservationIgnored private let folder: URL

    /// `folder` is only changed by tests (a temporary folder).
    init(folder: URL? = nil) {
        self.folder = folder ?? Self.soundsFolder
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Add

    func add(from source: URL, suggestedName: String) async throws -> CustomSound {
        guard sounds.count < Self.maxSounds else { throw SoundClipMaker.ImportError.tooMany }
        Trace.log(.audio, "CustomSoundLibrary.add() → SoundClipMaker on a background thread")

        // LEARN: a file picked in the Files app belongs to another app's storage. iOS lends it to us
        // through a "security-scoped" URL: we must say when we start and stop reading it.
        // (For our own temporary files this simply returns false and does nothing.)
        let isScoped = source.startAccessingSecurityScopedResource()
        defer { if isScoped { source.stopAccessingSecurityScopedResource() } }

        let id = UUID()
        // WHY a temporary name first: if the app is killed halfway, a broken half-file must never
        // look like a real sound. A finished clip is renamed in one step (a rename can't be half-done).
        let temporary = folder.appendingPathComponent(".importing-\(id.uuidString).caf")
        defer { try? FileManager.default.removeItem(at: temporary) }

        let duration = try await SoundClipMaker.makeClip(from: source, to: temporary)   // → background thread
        do {
            try FileManager.default.moveItem(at: temporary, to: url(for: id))
        } catch {
            throw SoundClipMaker.ImportError.couldNotSave
        }
        let sound = CustomSound(id: id, name: uniqueName(Self.cleanName(suggestedName)),
                                duration: duration, createdAt: .now)
        sounds.insert(sound, at: 0)
        saveManifest()
        Trace.log(.audio, "CustomSoundLibrary.add() → saved \(Trace.short(id)), \(Int(duration)) s")
        return sound
    }

    // MARK: - Rename / delete

    func rename(_ id: UUID, to name: String) {
        let cleaned = Self.cleanName(name, fallback: "")
        guard !cleaned.isEmpty, let index = sounds.firstIndex(where: { $0.id == id }) else { return }
        sounds[index].name = uniqueName(cleaned, ignoring: id)
        saveManifest()
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        sounds.removeAll { $0.id == id }
        saveManifest()
        Trace.log(.audio, "CustomSoundLibrary.delete(\(Trace.short(id)))")
    }

    func choice(for soundName: String) -> SoundChoice { resolve(soundName) }

    // MARK: - Names

    /// "  my_morning_song  " → "my morning song"; too long → cut at 40 characters; nothing left → fallback.
    nonisolated static func cleanName(_ raw: String, fallback: String = "My sound") -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let cut = String(spaced.prefix(maxNameLength)).trimmingCharacters(in: .whitespaces)
        return cut.isEmpty ? fallback : cut
    }

    // MARK: - Files

    private func url(for id: UUID) -> URL {
        folder.appendingPathComponent(CustomSound.fileName(for: id))
    }

    /// Reads the folder: every custom .caf is a sound; the JSON adds its name.
    private func load() {
        let manifest = (try? Data(contentsOf: folder.appendingPathComponent(Self.manifestName)))
            .flatMap { try? JSONDecoder().decode([CustomSound].self, from: $0) } ?? []
        let named = Dictionary(manifest.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []

        var found: [CustomSound] = []
        for file in files {
            let name = file.lastPathComponent
            if name.hasPrefix(".importing-") {                       // left over from a killed import
                try? FileManager.default.removeItem(at: file)
                continue
            }
            guard let id = CustomSound.id(fromFileName: name) else { continue }
            // A file without a name in the JSON is kept, not deleted: it's still a working sound.
            found.append(named[id] ?? CustomSound(id: id, name: "My sound", duration: Self.duration(of: file),
                                                  createdAt: .now))
        }
        sounds = found.sorted { $0.createdAt > $1.createdAt }
        if sounds.map(\.id) != manifest.map(\.id) { saveManifest() }    // forget names of missing files
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(sounds) else { return }
        try? data.write(to: folder.appendingPathComponent(Self.manifestName), options: .atomic)
    }

    nonisolated private static func duration(of file: URL) -> Double {
        guard let audio = try? AVAudioFile(forReading: file) else { return 0 }
        return Double(audio.length) / audio.fileFormat.sampleRate
    }
}

/// Fake for Previews and tests: keeps sounds in memory, makes no files.
@Observable
final class MockCustomSoundLibrary: CustomSoundStoring {
    private(set) var sounds: [CustomSound]

    init(sounds: [CustomSound] = []) { self.sounds = sounds }

    func add(from source: URL, suggestedName: String) async throws -> CustomSound {
        let sound = CustomSound(id: UUID(), name: uniqueName(CustomSoundLibrary.cleanName(suggestedName)),
                                duration: 30, createdAt: .now)
        sounds.insert(sound, at: 0)
        return sound
    }
    func rename(_ id: UUID, to name: String) {
        guard let index = sounds.firstIndex(where: { $0.id == id }) else { return }
        sounds[index].name = name
    }
    func delete(_ id: UUID) { sounds.removeAll { $0.id == id } }
    func choice(for soundName: String) -> SoundChoice { resolve(soundName) }
}
