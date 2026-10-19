//
//  CustomSoundTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for the user's own sounds and the sound search (#37)
//  WHAT:  POSITIVE: WAV, M4A (stereo, 48 kHz), a video's sound, quiet recordings, silence at the start,
//                   short "dings", long songs (cut at 30 s, fast), names, rename, persistence, search.
//         NEGATIVE: not audio, an empty file, silence, a click, a video without sound, too many sounds,
//                   a damaged/missing name list, deleting a sound an alarm uses, a deleted sound's alarm.
//  DATA:  every audio file is MADE by the test (sine tones) in a temporary folder, deleted afterwards.
//
//  CONNECTIONS:
//    → TESTS: SoundClipMaker, CustomSoundLibrary, SoundPickerViewModel, AlarmSoundRule, AudioService.fileURL,
//             AlarmEditorViewModel (save/reopen), RingingViewModel (plays it), WidgetBridge.plan (title)
//

import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import Alarm

// MARK: - Test audio files

/// Makes real audio and video files to import.
nonisolated enum AudioFixtures {
    /// A temporary folder, deleted by the caller.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sounds-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A sine tone. `silenceBefore` seconds of silence first. `aac: true` → .m4a (AAC), else .wav (PCM).
    /// WHY `@concurrent`: encoding minutes of audio is real work. On the main thread it starved other
    /// tests' timers (the Memory mission test failed once because of it).
    @concurrent
    static func tone(in folder: URL, seconds: Double, silenceBefore: Double = 0, amplitude: Float = 0.5,
                     sampleRate: Double = 44_100, channels: AVAudioChannelCount = 1, aac: Bool = false,
                     name: String = "tone") async throws -> URL {
        let url = folder.appendingPathComponent(name).appendingPathExtension(aac ? "m4a" : "wav")
        let settings: [String: Any] = aac
            ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate,
               AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: 128_000]
            : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: channels,
               AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let total = Int((silenceBefore + seconds) * sampleRate)
        let silent = Int(silenceBefore * sampleRate)
        let chunk = 44_100
        var written = 0
        while written < total {
            let count = min(chunk, total - written)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(count))!
            buffer.frameLength = AVAudioFrameCount(count)
            for channel in 0..<Int(channels) {
                let data = buffer.floatChannelData![channel]
                for i in 0..<count {
                    let n = written + i
                    data[i] = n < silent ? 0 : amplitude * sin(2 * .pi * 440 * Float(n) / Float(sampleRate))
                }
            }
            try file.write(from: buffer)
            written += count
        }
        file.close()
        return url
    }

    /// A short video WITHOUT sound (two black frames).
    static func silentVideo(in folder: URL, seconds: Double = 2) async throws -> URL {
        let url = folder.appendingPathComponent("video-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        var pixels: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixels)
        for time in [0, seconds] {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(pixels!, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    /// A video WITH sound: the silent video + `audio` put together (like a phone video).
    static func video(in folder: URL, withSoundOf audio: URL) async throws -> URL {
        let video = try await silentVideo(in: folder, seconds: 5)
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video), audioAsset = AVURLAsset(url: audio)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        let videoTrack = try await videoAsset.loadTracks(withMediaType: .video)[0]
        let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio)[0]
        try composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
            .insertTimeRange(range, of: videoTrack, at: .zero)
        try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            .insertTimeRange(range, of: audioTrack, at: .zero)
        let url = folder.appendingPathComponent("with-sound-\(UUID().uuidString).mov")
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
        try await export.export(to: url, as: .mov)
        return url
    }

    /// What a made clip looks like inside: format, length and loudness.
    struct ClipFacts {
        let formatID: AudioFormatID, sampleRate: Double, channels: AVAudioChannelCount
        let seconds: Double, peak: Float, startLevel: Float
    }

    static func facts(of url: URL) throws -> ClipFacts {
        let file = try AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        let startCount = min(Int(0.1 * file.fileFormat.sampleRate), samples.count)
        let start = samples.prefix(startCount).map { $0 * $0 }.reduce(0, +) / Float(max(startCount, 1))
        return ClipFacts(formatID: file.fileFormat.streamDescription.pointee.mFormatID,
                         sampleRate: file.fileFormat.sampleRate,
                         channels: file.fileFormat.channelCount,
                         seconds: Double(file.length) / file.fileFormat.sampleRate,
                         peak: samples.reduce(0) { max($0, abs($1)) },
                         startLevel: start.squareRoot())
    }
}

// MARK: - Making the clip

@Suite("Custom sounds: making the alarm clip")
struct SoundClipMakerTests {

    private func make(_ source: URL, in folder: URL) async throws -> AudioFixtures.ClipFacts {
        let clip = folder.appendingPathComponent("clip-\(UUID().uuidString).caf")
        _ = try await SoundClipMaker.makeClip(from: source, to: clip)
        return try AudioFixtures.facts(of: clip)
    }

    @Test("A WAV becomes a CAF exactly like our own sounds: IMA4, 44.1 kHz, mono")
    func wavFormat() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let facts = try await make(try await AudioFixtures.tone(in: folder, seconds: 20), in: folder)
        #expect(facts.formatID == kAudioFormatAppleIMA4)
        #expect(facts.sampleRate == 44_100)
        #expect(facts.channels == 1)
        #expect(abs(facts.seconds - 20) < 0.1)
    }

    @Test("A 2-minute stereo 48 kHz M4A song is cut at 30 s, mixed to mono, and is quick")
    func longSongIsCut() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let song = try await AudioFixtures.tone(in: folder, seconds: 120, sampleRate: 48_000, channels: 2, aac: true)
        let clock = ContinuousClock()
        let started = clock.now
        let facts = try await make(song, in: folder)
        let took = clock.now - started
        #expect(abs(facts.seconds - SoundClipMaker.maxClipSeconds) < 0.05)
        #expect(facts.channels == 1 && facts.sampleRate == 44_100)
        // Only the first 30 s are decoded, so a long song is as fast as a short one.
        print("⏱ 2-minute song → clip in \(took)")
        #expect(took < .seconds(2), "took \(took)")
    }

    @Test("Silence at the start is skipped: the clip begins with sound")
    func skipsLeadingSilence() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let facts = try await make(try await AudioFixtures.tone(in: folder, seconds: 20, silenceBefore: 4), in: folder)
        #expect(abs(facts.seconds - 20) < 0.1, "the 4 silent seconds are gone")
        #expect(facts.startLevel > 0.1, "the first 0.1 s already rings")
    }

    @Test("A quiet recording is made loud (normalised to about −1 dB)")
    func normalises() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let facts = try await make(try await AudioFixtures.tone(in: folder, seconds: 20, amplitude: 0.08), in: folder)
        #expect(abs(facts.peak - SoundClipMaker.targetPeak) < 0.08, "peak \(facts.peak)")
    }

    @Test("A short 'ding' is repeated to fill the clip, like an alarm beep")
    func repeatsShortSounds() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let facts = try await make(try await AudioFixtures.tone(in: folder, seconds: 0.5), in: folder)
        #expect(facts.seconds > 25 && facts.seconds <= SoundClipMaker.maxClipSeconds + 0.01)
    }

    @Test("The sound of a video (Photos) is used")
    func videoWithSound() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let audio = try await AudioFixtures.tone(in: folder, seconds: 5, aac: true)
        let video = try await AudioFixtures.video(in: folder, withSoundOf: audio)
        let facts = try await make(video, in: folder)
        #expect(facts.seconds > 20, "5 s of sound, repeated")
        #expect(facts.peak > 0.5)
    }

    // MARK: Negative

    @Test("A text file pretending to be an MP3 is refused")
    func notAudio() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let fake = folder.appendingPathComponent("song.mp3")
        try Data("definitely not music".utf8).write(to: fake)
        await #expect(throws: SoundClipMaker.ImportError.unreadable) {
            _ = try await SoundClipMaker.makeClip(from: fake, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("An empty file is refused")
    func emptyFile() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let empty = folder.appendingPathComponent("empty.m4a")
        try Data().write(to: empty)
        await #expect(throws: SoundClipMaker.ImportError.unreadable) {
            _ = try await SoundClipMaker.makeClip(from: empty, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("Pure silence is refused")
    func silence() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let quiet = try await AudioFixtures.tone(in: folder, seconds: 10, amplitude: 0)
        await #expect(throws: SoundClipMaker.ImportError.silent) {
            _ = try await SoundClipMaker.makeClip(from: quiet, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("Sound that only starts after 30 s of silence is refused (we never search further)")
    func lateSound() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let late = try await AudioFixtures.tone(in: folder, seconds: 5, silenceBefore: 35)
        await #expect(throws: SoundClipMaker.ImportError.silent) {
            _ = try await SoundClipMaker.makeClip(from: late, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("A click shorter than a quarter second is refused")
    func click() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let click = try await AudioFixtures.tone(in: folder, seconds: 0.1)
        await #expect(throws: SoundClipMaker.ImportError.tooShort) {
            _ = try await SoundClipMaker.makeClip(from: click, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("A video without sound says so")
    func videoWithoutSound() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let video = try await AudioFixtures.silentVideo(in: folder)
        await #expect(throws: SoundClipMaker.ImportError.noAudio) {
            _ = try await SoundClipMaker.makeClip(from: video, to: folder.appendingPathComponent("x.caf"))
        }
    }

    @Test("Shaping rules: the tail's silence is trimmed and fades remove clicks")
    func shapeRules() throws {
        var samples = [Float](repeating: 0.5, count: 44_100 * 20) + [Float](repeating: 0, count: 44_100)
        samples = try SoundClipMaker.shape(samples)
        #expect(samples.count == 44_100 * 20, "the silent second at the end is gone")
        #expect(samples.first == 0 && abs(samples.last ?? 1) < 0.01, "fades at both ends")
    }
}

// MARK: - The library

@Suite("Custom sounds: the library")
struct CustomSoundLibraryTests {

    @Test("Adding saves the clip in the folder AND remembers its name after a restart")
    func addAndReload() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let source = try await AudioFixtures.tone(in: folder, seconds: 20, name: "my_morning_song")
        let soundsFolder = folder.appendingPathComponent("Sounds")
        let library = CustomSoundLibrary(folder: soundsFolder)

        let sound = try await library.add(from: source, suggestedName: "my_morning_song")
        #expect(sound.name == "my morning song")
        #expect(FileManager.default.fileExists(atPath: soundsFolder.appendingPathComponent(sound.fileName).path))
        #expect(sound.fileName.hasPrefix(CustomSound.filePrefix))

        let reopened = CustomSoundLibrary(folder: soundsFolder)          // like the next app launch
        #expect(reopened.sounds == [sound])
        #expect(reopened.choice(for: sound.fileName) == .custom(sound))
    }

    @Test("Names: tidied, cut at 40 characters, never empty, never twice the same")
    func names() async throws {
        #expect(CustomSoundLibrary.cleanName("  my_song \n final ") == "my song final")
        #expect(CustomSoundLibrary.cleanName("   ") == "My sound")
        #expect(CustomSoundLibrary.cleanName(String(repeating: "a", count: 80)).count == 40)

        let library = MockCustomSoundLibrary()
        let first = try await library.add(from: URL(fileURLWithPath: "/x"), suggestedName: "Song")
        let second = try await library.add(from: URL(fileURLWithPath: "/x"), suggestedName: "song")
        #expect(first.name == "Song" && second.name == "song 2")
    }

    @Test("Rename: blank names are ignored, taken names get a number")
    func rename() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let library = CustomSoundLibrary(folder: folder.appendingPathComponent("Sounds"))
        let a = try await library.add(from: try await AudioFixtures.tone(in: folder, seconds: 2, name: "a"), suggestedName: "Alpha")
        let b = try await library.add(from: try await AudioFixtures.tone(in: folder, seconds: 2, name: "b"), suggestedName: "Beta")
        library.rename(a.id, to: "   ")
        #expect(library.sounds.first { $0.id == a.id }?.name == "Alpha")
        library.rename(b.id, to: "alpha")
        #expect(library.sounds.first { $0.id == b.id }?.name == "alpha 2")
    }

    @Test("Delete removes the file; an alarm still naming it means iOS's own tone")
    func delete() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let soundsFolder = folder.appendingPathComponent("Sounds")
        let library = CustomSoundLibrary(folder: soundsFolder)
        let sound = try await library.add(from: try await AudioFixtures.tone(in: folder, seconds: 3), suggestedName: "Gone")
        library.delete(sound.id)
        #expect(library.sounds.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: soundsFolder.appendingPathComponent(sound.fileName).path))
        #expect(library.choice(for: sound.fileName) == .builtIn(.systemDefault))
    }

    @Test("A lost or damaged name list never loses a sound; half-finished imports are cleaned up")
    func survivesDamage() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let soundsFolder = folder.appendingPathComponent("Sounds")
        let library = CustomSoundLibrary(folder: soundsFolder)
        let sound = try await library.add(from: try await AudioFixtures.tone(in: folder, seconds: 20), suggestedName: "Keep me")
        try Data("{ broken".utf8).write(to: soundsFolder.appendingPathComponent(CustomSoundLibrary.manifestName))
        try Data("half".utf8).write(to: soundsFolder.appendingPathComponent(".importing-\(UUID().uuidString).caf"))

        let reopened = CustomSoundLibrary(folder: soundsFolder)
        #expect(reopened.sounds.map(\.id) == [sound.id], "the file is the truth")
        #expect(reopened.sounds.first?.name == "My sound")
        #expect(abs((reopened.sounds.first?.duration ?? 0) - 20) < 0.1)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: soundsFolder.path).filter { $0.hasPrefix(".importing-") }
        #expect(leftovers.isEmpty)
    }

    @Test("A failed import leaves no file behind")
    func failedImportIsClean() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let soundsFolder = folder.appendingPathComponent("Sounds")
        let library = CustomSoundLibrary(folder: soundsFolder)
        let fake = folder.appendingPathComponent("fake.wav")
        try Data("nope".utf8).write(to: fake)
        await #expect(throws: SoundClipMaker.ImportError.unreadable) {
            _ = try await library.add(from: fake, suggestedName: "Fake")
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: soundsFolder.path)
            .filter { $0 != CustomSoundLibrary.manifestName }
        #expect(files.isEmpty && library.sounds.isEmpty)
    }

    @Test("At most 50 sounds")
    func limit() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let soundsFolder = folder.appendingPathComponent("Sounds")
        let first = CustomSoundLibrary(folder: soundsFolder)
        let sound = try await first.add(from: try await AudioFixtures.tone(in: folder, seconds: 1), suggestedName: "One")
        let file = soundsFolder.appendingPathComponent(sound.fileName)
        for _ in 1..<CustomSoundLibrary.maxSounds {
            try FileManager.default.copyItem(at: file, to: soundsFolder.appendingPathComponent(CustomSound.fileName(for: UUID())))
        }
        let full = CustomSoundLibrary(folder: soundsFolder)
        #expect(full.sounds.count == CustomSoundLibrary.maxSounds)
        await #expect(throws: SoundClipMaker.ImportError.tooMany) {
            _ = try await full.add(from: try await AudioFixtures.tone(in: folder, seconds: 1, name: "two"), suggestedName: "Two")
        }
    }

    @Test("What iOS really gets: our files, the user's files, and iOS's tone for a missing one")
    func alarmKitRule() {
        let custom = CustomSound.fileName(for: UUID())
        #expect(AlarmSoundRule.usesSystemSound("default", fileExists: { _ in true }))
        #expect(!AlarmSoundRule.usesSystemSound("riseup_radar.caf", fileExists: { _ in false }), "ours live in the app")
        #expect(!AlarmSoundRule.usesSystemSound(custom, fileExists: { _ in true }))
        #expect(AlarmSoundRule.usesSystemSound(custom, fileExists: { _ in false }))
        #expect(CustomSound.id(fromFileName: "riseup_custom_garbage.caf") == nil)
    }

    @Test("In the app, a missing custom file plays Digital instead of nothing")
    func audioFallback() {
        let missing = CustomSound(id: UUID(), name: "Gone", duration: 30, createdAt: .now)
        #expect(AudioService.fileURL(for: .custom(missing))?.lastPathComponent == AlarmSound.digital.rawValue)
        #expect(AudioService.fileURL(for: .builtIn(.radar))?.lastPathComponent == AlarmSound.radar.rawValue)
    }
}

// MARK: - The picker, the editor, the ringing screen

@Suite("Custom sounds: picker, search and the rest of the app")
struct SoundPickerTests {
    /// WHY keep the container: a context whose container is gone crashes (found in this test file).
    let container: ModelContainer
    let repository: AlarmRepository
    let audio = MockAudioService()
    let coordinator = AppCoordinator()

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        repository = AlarmRepository(context: container.mainContext)
    }

    func makePicker(_ library: any CustomSoundStoring = MockCustomSoundLibrary(),
                    selected: SoundChoice = .builtIn(.radar), allowsCustom: Bool = true) -> SoundPickerViewModel {
        SoundPickerViewModel(selected: selected, allowsCustom: allowsCustom, audio: audio,
                             customSounds: library, alarmRepository: repository, coordinator: coordinator)
    }

    @Test("Search: by name, description or group; any case; accents; several words")
    func search() {
        let picker = makePicker()
        picker.searchText = "rain"
        let found = picker.visibleCategories.flatMap(\.sounds)
        #expect(found.contains(.rainforest) && found.contains(.thunderstorm))
        picker.searchText = "BELL"
        #expect(picker.visibleCategories.flatMap(\.sounds).contains(.twinBell))
        picker.searchText = "cafe"                           // "a café waltz"
        #expect(picker.visibleCategories.flatMap(\.sounds) == [.accordion])
        picker.searchText = "world drum"
        #expect(Set(picker.visibleCategories.flatMap(\.sounds)) == [.savannaDrums, .steelDrum, .desertOud], "Desert Oud: \"…and frame drum\"")
        picker.searchText = "zzzz"
        #expect(picker.hasNoResults)
        picker.searchText = "   "
        #expect(!picker.isSearching && picker.visibleCategories.count == AlarmSound.Category.allCases.count)
    }

    @Test("Search finds your own sounds too; Settings' default picker never shows them")
    func searchCustom() {
        let mine = CustomSound(id: UUID(), name: "Morning song", duration: 30, createdAt: .now)
        let picker = makePicker(MockCustomSoundLibrary(sounds: [mine]))
        picker.searchText = "morning"
        #expect(picker.visibleCustomSounds == [mine])
        #expect(picker.visibleCategories.flatMap(\.sounds).contains(.birds), "Morning Birds too")
        let settingsPicker = makePicker(MockCustomSoundLibrary(sounds: [mine]), allowsCustom: false)
        #expect(settingsPicker.visibleCustomSounds.isEmpty)
    }

    @Test("Adding a sound selects it and plays it; a bad file shows a message and changes nothing")
    func addFromPicker() async throws {
        let folder = try AudioFixtures.folder(); defer { try? FileManager.default.removeItem(at: folder) }
        let picker = makePicker(CustomSoundLibrary(folder: folder.appendingPathComponent("Sounds")))
        picker.searchText = "something"

        await picker.addSound(from: try await AudioFixtures.tone(in: folder, seconds: 3), suggestedName: "Beep")
        guard case .custom(let added) = picker.selected else { Issue.record("not selected"); return }
        #expect(added.name == "Beep")
        #expect(audio.previewedSound == .custom(added))
        #expect(picker.searchText.isEmpty && !picker.isImporting && picker.alertMessage == nil)

        let fake = folder.appendingPathComponent("fake.mp3")
        try Data("x".utf8).write(to: fake)
        await picker.addSound(from: fake, suggestedName: "Fake")
        #expect(picker.alertMessage == SoundClipMaker.ImportError.unreadable.errorDescription)
        #expect(picker.selected == .custom(added), "the selection didn't change")
        #expect(!picker.isImporting)
    }

    @Test("A sound an alarm uses can't be deleted; an unused one can, and the selection moves on")
    func deleteRules() throws {
        let used = CustomSound(id: UUID(), name: "Used", duration: 30, createdAt: .now)
        let free = CustomSound(id: UUID(), name: "Free", duration: 30, createdAt: .now)
        let library = MockCustomSoundLibrary(sounds: [used, free])
        try repository.insert(WakeAlarm(hour: 7, minute: 0, isEnabled: false, soundName: used.fileName))
        let picker = makePicker(library, selected: .custom(free))

        picker.askToDelete(used)
        #expect(picker.deleting == nil && picker.alertMessage?.contains("an alarm") == true)
        #expect(library.sounds.count == 2)

        picker.askToDelete(free)
        picker.confirmDelete()
        #expect(library.sounds == [used])
        #expect(picker.selected == .builtIn(.radar))
    }

    @Test("Renaming the selected sound updates its name in the answer to the editor")
    func renameSelected() {
        let mine = CustomSound(id: UUID(), name: "Old", duration: 30, createdAt: .now)
        let library = MockCustomSoundLibrary(sounds: [mine])
        let picker = makePicker(library, selected: .custom(mine))
        picker.startRename(mine)
        picker.renameText = "New"
        picker.confirmRename()
        #expect(picker.selected.title == "New")
    }

    @Test("Editor round trip: choose your sound, save, reopen; the alarm rings with it")
    func editorAndRinging() async throws {
        let mine = CustomSound(id: UUID(), name: "Mine", duration: 30, createdAt: .now)
        let library = MockCustomSoundLibrary(sounds: [mine])
        let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
        let editor = AlarmEditorViewModel(alarmID: nil, repository: repository, scheduler: MockAlarmScheduler(),
                                          settings: settings, wallpaperStore: MockWallpaperStore(),
                                          customSounds: library, coordinator: coordinator)
        editor.chooseSound()
        #expect(coordinator.sheet == .soundPicker(selected: editor.draft.sound, allowsCustom: true))
        makePicker(library).select(.custom(mine))
        coordinator.completeSoundPicker(with: .custom(mine))
        #expect(editor.draft.sound == .custom(mine))
        await editor.save()

        let saved = try #require(repository.alarms.first)
        #expect(saved.soundName == mine.fileName)
        let reopened = AlarmEditorViewModel(alarmID: saved.id, repository: repository, scheduler: MockAlarmScheduler(),
                                            settings: settings, wallpaperStore: MockWallpaperStore(),
                                            customSounds: library, coordinator: coordinator)
        #expect(reopened.draft.sound == .custom(mine))

        let ringing = RingingViewModel(alarmID: saved.id, repository: repository,
                                       records: WakeRecordRepository(context: container.mainContext),
                                       scheduler: MockAlarmScheduler(), audio: audio, timeAnnouncer: MockTimeAnnouncer(),
                                       sleepSounds: MockSleepSoundPlayer(), settings: settings,
                                       wallpaperStore: MockWallpaperStore(), customSounds: library,
                                       missionServices: .preview(), coordinator: coordinator)
        ringing.start()
        #expect(audio.alarmSound == .custom(mine))

        let widget = WidgetBridge.plan(alarms: [saved], defaultWallpaper: .standard, now: .now,
                                       soundTitle: { library.choice(for: $0).title })
        #expect(widget.first?.event.soundTitle == "Mine")
    }

    @Test("Settings' default sound picker only offers our sounds")
    func settingsDefault() {
        let settings = AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
        let deps = AppDependencies.preview()
        let viewModel = SettingsViewModel(settings: settings, alarmSync: deps.alarmSync, coordinator: coordinator)
        viewModel.chooseDefaultSound()
        #expect(coordinator.sheet == .soundPicker(selected: .builtIn(settings.defaultSound), allowsCustom: false))
    }
}
