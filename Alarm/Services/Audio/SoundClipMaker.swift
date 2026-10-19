//
//  SoundClipMaker.swift
//  RiseUp
//
//  LAYER: Service helper (pure audio maths + AVFoundation file reading/writing, no UI, no state)
//  WHAT:  Turns ANY audio the user picks (MP3, M4A, WAV, AIFF, CAF… or the sound of a video)
//         into a clip an alarm can play: up to 30 s, loud enough, no silence at the start,
//         in the same format as our own sounds (CAF, IMA4, 44.1 kHz, mono).
//  DATA:  reads the source file, writes ONE new .caf file. Keeps nothing.
//
//  CONNECTIONS:
//    ← CALLED BY: CustomSoundLibrary.add(from:suggestedName:)
//    ← TESTED BY: RiseUpTests/CustomSoundTests (real files: songs, videos, silence, garbage…)
//    → USES:      AVAssetReader (decodes any format AVFoundation knows, including video files),
//                 AVAudioFile (writes the .caf)
//
//  WHY a clip instead of the whole song:
//    • iOS plays an alarm's sound from a file it finds by name. Apple's limit for those sounds is
//      30 seconds, and that's the length that is known to work.
//    • Reading only the first seconds is what makes adding a sound FAST: a 1-hour video and a
//      10-second ringtone take the same ~0.1 s, because we stop reading after the clip.
//  WHY these steps (each one fixes a real-world problem with people's files):
//    1. skip silence at the start   → videos often start quiet; an alarm that "rings" silence is broken
//    2. mix to mono, 44.1 kHz         → one format for everything; stereo doesn't matter on a phone speaker
//    3. normalise the loudness       → a quiet voice memo becomes as loud as our sounds
//    4. repeat very short sounds     → a 1-second "ding" fills ~30 s, like a real alarm beep
//    5. short fades                  → no "click" where the clip starts, ends or repeats
//

import Accelerate
import AVFoundation
import Foundation

nonisolated enum SoundClipMaker {

    // MARK: - The numbers (TRY: change one and run CustomSoundTests to see what it affects)

    /// Longest clip we save. Apple's limit for named alarm/notification sounds is 30 s.
    static let maxClipSeconds: Double = 30
    /// We skip at most this much silence at the start. Nothing audible by then → "silent".
    static let maxLeadingSilenceSeconds: Double = 30
    /// Shorter than this isn't a sound, it's a click.
    static let minAudibleSeconds: Double = 0.25
    /// Sounds shorter than this are repeated (with a small gap) to fill the clip.
    static let repeatBelowSeconds: Double = 15
    static let repeatGapSeconds: Double = 0.4
    /// Anything quieter than this counts as silence (≈ −50 dB, a very quiet room).
    static let silenceLevel: Float = 0.003
    /// Normalising raises the loudest point to this (≈ −1 dB: as loud as possible without distortion)…
    static let targetPeak: Float = 0.89
    /// …but never by more than ×16 (+24 dB), so a recording of hiss doesn't become a roar of hiss.
    static let maxGain: Float = 16
    static let sampleRate: Double = 44_100

    /// What went wrong, in words a user understands (shown in an alert by the Sound Picker).
    enum ImportError: LocalizedError, Equatable {
        case unreadable, noAudio, protected, silent, tooShort, couldNotSave, couldNotLoad, tooMany

        var errorDescription: String? {
            switch self {
            case .unreadable: "This file can't be played. Try an MP3, M4A or WAV file, or a video."
            case .noAudio: "This video has no sound."
            case .protected: "This song is copy-protected (for example from Apple Music), so iOS doesn't let apps use it."
            case .silent: "We couldn't hear anything in its first 30 seconds."
            case .tooShort: "This sound is too short to wake anyone up."
            case .couldNotSave: "The sound couldn't be saved. Is your iPhone's storage full?"
            case .couldNotLoad: "That video couldn't be loaded. If it's in iCloud, check your internet connection and try again."
            case .tooMany: "You've added \(CustomSoundLibrary.maxSounds) sounds. Delete one to add another."
            }
        }
    }

    // MARK: - The whole job

    /// Reads `source`, makes the alarm clip and writes it to `destination` (a .caf). Returns its length in seconds.
    ///
    /// LEARN: `@concurrent` = runs on a background thread. Decoding audio is real work; on the main
    /// thread it would freeze the Sound Picker while the spinner should be spinning.
    @concurrent
    static func makeClip(from source: URL, to destination: URL) async throws -> Double {
        let samples = try await readSamples(from: source)
        let clip = try shape(samples)
        try write(clip, to: destination)
        return Double(clip.count) / sampleRate
    }

    // MARK: - Step 1: read (decode) the first seconds

    /// Mono 44.1 kHz samples from the first audible moment on (at most `maxClipSeconds` of them).
    @concurrent
    static func readSamples(from source: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: source)
        // LEARN: AVFoundation loads facts about a file lazily; `load` asks for them (async, may throw).
        let tracks: [AVAssetTrack]
        do {
            guard try await asset.load(.isReadable) else { throw ImportError.unreadable }
            if try await asset.load(.hasProtectedContent) { throw ImportError.protected }
            tracks = try await asset.load(.tracks)
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.unreadable
        }
        guard !tracks.isEmpty else { throw ImportError.unreadable }            // not a media file at all
        let audioTracks = tracks.filter { $0.mediaType == .audio }
        guard !audioTracks.isEmpty else { throw ImportError.noAudio }          // e.g. a silent screen recording

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { throw ImportError.unreadable }
        // LEARN: the "mix output" decodes every audio track and mixes them into the format we ask
        // for. AVFoundation converts the sample rate and the number of channels for us.
        let output = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
        ])
        guard reader.canAdd(output) else { throw ImportError.unreadable }
        reader.add(output)
        // WHY a time range: decode only what we might need, never the whole file. This is THE speed trick.
        reader.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: maxLeadingSilenceSeconds + maxClipSeconds, preferredTimescale: 600)
        )
        guard reader.startReading() else { throw ImportError.unreadable }

        let maxSilent = Int(maxLeadingSilenceSeconds * sampleRate)
        let maxKept = Int(maxClipSeconds * sampleRate)
        var kept: [Float] = []
        kept.reserveCapacity(maxKept)
        var skipped = 0                          // silent samples at the start, thrown away
        var heardSomething = false

        // WHY whole chunks (not sample by sample): a chunk is thousands of samples, and copying it in
        // one go is ~50× faster than a Swift loop, especially in Debug builds run from Xcode.
        while kept.count < maxKept, let buffer = output.copyNextSampleBuffer() {
            var chunk = floats(in: buffer)[...]
            if !heardSomething {
                guard let first = chunk.firstIndex(where: { abs($0) >= silenceLevel }) else {
                    skipped += chunk.count                               // all silent: throw it away
                    if skipped >= maxSilent { reader.cancelReading(); throw ImportError.silent }
                    continue
                }
                skipped += first - chunk.startIndex
                if skipped >= maxSilent { reader.cancelReading(); throw ImportError.silent }
                chunk = chunk[first...]                                  // keep from the first sound on
                heardSomething = true
            }
            kept.append(contentsOf: chunk.prefix(maxKept - kept.count))
        }
        if kept.count == maxKept {
            reader.cancelReading()               // we have enough: stop decoding right here
        } else if reader.status == .failed {
            throw ImportError.unreadable
        }
        guard heardSomething else { throw ImportError.silent }
        return kept
    }

    /// The float samples inside one decoded chunk.
    private static func floats(in buffer: CMSampleBuffer) -> [Float] {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return [] }
        let byteCount = CMBlockBufferGetDataLength(block)
        var samples = [Float](repeating: 0, count: byteCount / MemoryLayout<Float>.size)
        // LEARN: `withUnsafeMutableBytes` hands C code a pointer to the array's memory, so the
        // bytes are copied straight in, without making an extra copy first.
        let status = samples.withUnsafeMutableBytes { raw in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: raw.baseAddress!)
        }
        return status == kCMBlockBufferNoErr ? samples : []
    }

    // MARK: - Steps 2–5: shape the clip (pure maths, tested without any files)

    /// Trims the silent end, normalises, repeats a short sound and fades the edges.
    static func shape(_ input: [Float]) throws -> [Float] {
        // The silent tail goes (the start is already trimmed while reading).
        guard let lastAudible = input.lastIndex(where: { abs($0) >= silenceLevel }) else { throw ImportError.silent }
        var sound = Array(input[...lastAudible])
        guard Double(sound.count) / sampleRate >= minAudibleSeconds else { throw ImportError.tooShort }

        // Normalise: the loudest point becomes `targetPeak`.
        // LEARN: vDSP (Apple's Accelerate library) does maths on a whole array at once, using the
        // processor's vector instructions: much faster than a `for` loop over a million samples.
        let peak = vDSP.maximumMagnitude(sound)
        sound = vDSP.multiply(min(targetPeak / peak, maxGain), sound)

        let maxCount = Int(maxClipSeconds * sampleRate)
        let wasCut = sound.count >= maxCount
        if Double(sound.count) / sampleRate < repeatBelowSeconds {
            // A short "ding": repeat it, with a little gap, as often as fits in the clip.
            fade(&sound, inSeconds: 0.005, outSeconds: 0.005)
            let gap = [Float](repeating: 0, count: Int(repeatGapSeconds * sampleRate))
            var repeated = sound
            while repeated.count + gap.count + sound.count <= maxCount {
                repeated += gap + sound
            }
            return repeated
        }
        // A long sound cut at 30 s fades out over half a second instead of stopping mid-note.
        fade(&sound, inSeconds: 0.01, outSeconds: wasCut ? 0.5 : 0.02)
        return sound
    }

    /// Fades the first and last moments in and out (a straight line, enough to remove clicks).
    static func fade(_ samples: inout [Float], inSeconds: Double, outSeconds: Double) {
        let fadeIn = min(Int(inSeconds * sampleRate), samples.count)
        for i in 0..<fadeIn { samples[i] *= Float(i) / Float(fadeIn) }
        let fadeOut = min(Int(outSeconds * sampleRate), samples.count)
        for i in 0..<fadeOut { samples[samples.count - 1 - i] *= Float(i) / Float(fadeOut) }
    }

    // MARK: - Step 6: write the .caf

    /// Writes the samples as a CAF file in IMA4, exactly like the sounds made by Tools/generate_sounds.py.
    /// WHY IMA4: our own sounds use it and ring correctly on iPhones; it's ¼ the size of plain PCM.
    static func write(_ samples: [Float], to destination: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { throw ImportError.couldNotSave }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        do {
            let file = try AVAudioFile(forWriting: destination, settings: [
                AVFormatIDKey: kAudioFormatAppleIMA4,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
            ], commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
            file.close()                         // finishes the file now (the last IMA4 packet, the header)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw ImportError.couldNotSave
        }
    }
}
