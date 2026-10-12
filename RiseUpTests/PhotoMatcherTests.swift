//
//  PhotoMatcherTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing)
//  WHAT:  Checks the photo-matching plumbing with images DRAWN in code (no files needed):
//           • PixelPhotoMatcher (Simulator): same picture matches, a different one doesn't,
//             and a darker copy still matches (brightness is ignored)
//           • PhotoMissionPayload survives being saved and loaded
//  DATA:  none.
//
//  CONNECTIONS:
//    → TESTS: PixelPhotoMatcher, PhotoMissionPayload, CameraAccess.jpegData
//
//  WHY not test VisionPhotoMatcher here: tests run in the Simulator, where Vision's feature
//  prints don't work (see PixelPhotoMatcher's WHY). Vision is checked on a real iPhone using
//  the Debug distance shown in the Photo mission's practice mode.
//

import Foundation
import Testing
import UIKit
@testable import Alarm

@Suite("Photo matching")
struct PhotoMatcherTests {
    let matcher = PixelPhotoMatcher()

    /// Draws a test picture: `pattern` 0 = diagonal gradient, 1 = checkerboard. `dim` darkens it.
    func picture(_ pattern: Int, dim: CGFloat = 0) -> Data {
        let size = CGSize(width: 200, height: 150)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            for x in stride(from: 0, to: 200, by: 10) {
                for y in stride(from: 0, to: 150, by: 10) {
                    let value: CGFloat = pattern == 0
                        ? CGFloat(x + y) / 350
                        : ((x / 10 + y / 10).isMultiple(of: 2) ? 0.9 : 0.1)
                    UIColor(white: value * (1 - dim), alpha: 1).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 10, height: 10))
                }
            }
        }
        return CameraAccess.jpegData(from: image)!
    }

    @Test("The same picture matches itself")
    func samePicture() async throws {
        let a = try await matcher.fingerprint(of: picture(0))
        let b = try await matcher.fingerprint(of: picture(0))
        #expect(matcher.isMatch(distance: try matcher.distance(between: a, and: b)))
    }

    @Test("A darker copy still matches (brightness is ignored)")
    func darkerPicture() async throws {
        let a = try await matcher.fingerprint(of: picture(0))
        let b = try await matcher.fingerprint(of: picture(0, dim: 0.4))
        #expect(matcher.isMatch(distance: try matcher.distance(between: a, and: b)))
    }

    @Test("A different picture does not match")
    func differentPicture() async throws {
        let a = try await matcher.fingerprint(of: picture(0))
        let b = try await matcher.fingerprint(of: picture(1))
        #expect(!matcher.isMatch(distance: try matcher.distance(between: a, and: b)))
    }

    @Test("A photo payload survives saving and loading")
    func payloadRoundTrip() throws {
        let payload = PhotoMissionPayload(fingerprint: Data([1, 2, 3]), thumbnail: Data([4, 5]))
        #expect(PhotoMissionPayload.decode(try payload.encoded()) == payload)
        #expect(PhotoMissionPayload.decode(Data([0xFF])) == nil, "damaged data → nil, not a crash")
        #expect(PhotoMissionPayload.decode(nil) == nil)
    }
}
