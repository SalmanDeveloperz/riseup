//
//  PhotoMatcher.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  "Is this the same place as the registered photo?" using Apple's Vision framework.
//  DATA:  none stored. Turns photos into fingerprints and compares two fingerprints.
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (iPhone → VisionPhotoMatcher, Simulator → PixelPhotoMatcher,
//                  previews → MockPhotoMatcher)
//    ← USED BY:    MissionPickerViewModel (register), PhotoMissionViewModel (check)
//    → USES:       Vision (GenerateImageFeaturePrintRequest, FeaturePrintObservation)
//
//  LEARN: What's a "feature print"?
//  ────────────────────────────────
//  Vision looks at a photo and produces a list of 768 numbers that describe what's in it
//  (shapes, textures, objects), a bit like a fingerprint. Two photos of the same sink
//  give fingerprints that are CLOSE; a sink and a sofa give fingerprints that are FAR apart.
//  `distance(to:)` measures how far apart: small = similar.
//  It doesn't need the exact same angle or lighting, which is what we want at 6 a.m.
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

protocol PhotoMatching: AnyObject {
    /// JPEG data → fingerprint data (to save, or to compare).
    func fingerprint(of jpegData: Data) async throws -> Data
    /// How different two fingerprints are. 0 = identical. Throws for damaged data.
    func distance(between first: Data, and second: Data) throws -> Double
    /// Distances at or below this count as "the same place".
    var matchThreshold: Double { get }
}

extension PhotoMatching {
    /// ← USED BY: PhotoMissionViewModel
    func isMatch(distance: Double) -> Bool {
        distance <= matchThreshold
    }
}

final class VisionPhotoMatcher: PhotoMatching {
    /// TRY: if your photo mission fails too often, raise this (e.g. 0.75). Practice mode in the
    /// Mission Picker shows the measured distance in Debug builds so you can tune it.
    let matchThreshold = 0.65

    func fingerprint(of jpegData: Data) async throws -> Data {
        try await Self.makeFingerprint(jpegData)
    }

    func distance(between first: Data, and second: Data) throws -> Double {
        let decoder = JSONDecoder()
        let a = try decoder.decode(FeaturePrintObservation.self, from: first)
        let b = try decoder.decode(FeaturePrintObservation.self, from: second)
        return try a.distance(to: b)
    }

    /// The slow part (~0.1–0.5 s), done OFF the main thread so the UI never freezes.
    ///
    /// LEARN: `@concurrent` = "run this on a background thread", even though our project's
    /// default is the main actor. `nonisolated` + `static` + only `Data` (which is Sendable)
    /// going in and out keeps it safe: no main-actor state is touched in here.
    @concurrent
    nonisolated private static func makeFingerprint(_ jpegData: Data) async throws -> Data {
        let observation = try await GenerateImageFeaturePrintRequest().perform(on: jpegData)
        // LEARN: Vision's new observations are `Codable`, so saving one is a single line.
        return try JSONEncoder().encode(observation)
    }
}

/// A simple matcher for the SIMULATOR: compares tiny 16×16 grey versions of the photos.
///
/// WHY it exists: Vision's feature prints don't work in the Simulator. It either fails
/// ("Failed to create espresso context") or, forced onto the CPU, returns the SAME fingerprint
/// for every photo, so a flower would "match" a waterfall. We measured this with a test.
/// This matcher is far less clever than Vision (it can't handle a different angle), but it
/// tells different photos apart, so the whole flow (match AND no-match) can be tested.
///
/// LEARN: "z-normalising" (subtract the average, divide by the spread) makes the comparison
/// ignore overall brightness: the same photo a bit darker still looks the same.
final class PixelPhotoMatcher: PhotoMatching {
    /// Measured on the Simulator's sample photos: different photos 0.76–1.28, the same photo 0.
    let matchThreshold = 0.35
    private static let side = 16

    func fingerprint(of jpegData: Data) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(data: nil, width: Self.side, height: Self.side, bitsPerComponent: 8,
                                      bytesPerRow: Self.side, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        guard let pixels = context.data else { throw CocoaError(.fileReadCorruptFile) }
        return Data(bytes: pixels, count: Self.side * Self.side)
    }

    func distance(between first: Data, and second: Data) throws -> Double {
        guard first.count == second.count, !first.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let a = Self.normalised(first), b = Self.normalised(second)
        let total = zip(a, b).reduce(0.0) { $0 + abs($1.0 - $1.1) }
        return total / Double(a.count)
    }

    private static func normalised(_ data: Data) -> [Double] {
        let values = data.map(Double.init)
        let mean = values.reduce(0, +) / Double(values.count)
        let spread = max(1, (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot())
        return values.map { ($0 - mean) / spread }
    }
}

/// Fake matcher for Previews and tests: every photo "matches".
final class MockPhotoMatcher: PhotoMatching {
    let matchThreshold = 0.65
    func fingerprint(of jpegData: Data) async throws -> Data { Data([1, 2, 3]) }
    func distance(between first: Data, and second: Data) throws -> Double { 0.1 }
}
