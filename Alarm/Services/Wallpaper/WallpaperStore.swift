//
//  WallpaperStore.swift
//  RiseUp
//
//  LAYER: Service (protocol + real implementation + mock)
//  WHAT:  Keeps the user's own wallpaper photos: add (from the photo library), load, list, delete.
//  DATA:  JPEG files in Application Support/Wallpapers/<uuid>.jpg (NOT in the database: photos
//         are big; the database only stores the "photo.<uuid>" name in WakeAlarm.wallpaperID).
//
//  CONNECTIONS:
//    ← CREATED BY: AppDependencies (live → FileWallpaperStore, preview/tests → MockWallpaperStore)
//    ← USED BY:    WallpaperPickerViewModel (add/list/delete), RingingViewModel + AlarmEditorViewModel (load)
//    → USES:       FileManager, ImageIO (fast resizing/decoding off the main thread)
//
//  WHY "fast loading" is built in:
//    • Saving shrinks the photo to the screen size once (≈ 1290 px), so later loads are small.
//    • Loading decodes on a background thread and keeps the result in a memory cache, so the
//      Ringing screen gets it instantly the second time.
//

import Foundation
import ImageIO
import UIKit

protocol WallpaperStoring: AnyObject {
    /// Saves a photo (any size) as a new wallpaper; returns its id.
    func add(_ imageData: Data) async throws -> UUID
    /// The decoded photo, or nil if the file doesn't exist (any more).
    func image(for id: UUID) async -> UIImage?
    /// The user's photos, newest first.
    func photoIDs() -> [UUID]
    func delete(_ id: UUID)
}

/// Errors with messages a user can understand.
nonisolated enum WallpaperStoreError: LocalizedError {
    case unreadableImage
    var errorDescription: String? { "That picture couldn't be read. Please try another one." }
}

final class FileWallpaperStore: WallpaperStoring {
    private let folder: URL
    /// LEARN: NSCache is a dictionary that empties itself when the iPhone needs memory.
    private let cache = NSCache<NSUUID, UIImage>()

    /// Longest side when saving. TRY: 2000 for extra-sharp photos on big screens.
    nonisolated static let maxSide = 1290

    /// `folder` is only changed by tests (a temporary folder).
    init(folder: URL? = nil) {
        let base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wallpapers", isDirectory: true)
        self.folder = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    func add(_ imageData: Data) async throws -> UUID {
        let id = UUID()
        let url = fileURL(for: id)
        // → background thread: decode + shrink + save
        guard let jpeg = await Self.resizedJPEG(from: imageData, maxSide: Self.maxSide) else {
            throw WallpaperStoreError.unreadableImage
        }
        try jpeg.write(to: url, options: .atomic)
        return id
    }

    func image(for id: UUID) async -> UIImage? {
        if let cached = cache.object(forKey: id as NSUUID) { return cached }
        guard let image = await Self.decode(fileURL(for: id)) else { return nil }   // → background
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    func photoIDs() -> [UUID] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "jpg" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return l > r
            }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
    }

    func delete(_ id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).jpg")
    }

    // MARK: - Background work

    /// LEARN: `@concurrent` = runs on a background thread, so decoding a big photo never
    /// freezes the screen.
    @concurrent
    nonisolated private static func resizedJPEG(from data: Data, maxSide: Int) async -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,     // apply rotation from the camera
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }

    @concurrent
    nonisolated private static func decode(_ url: URL) async -> UIImage? {
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        // LEARN: `preparingForDisplay()` decodes the JPEG NOW (in the background) instead of at
        // the first frame on screen, which would cause a little stutter.
        return image.preparingForDisplay() ?? image
    }
}

/// Fake for Previews and tests: keeps photos in memory.
final class MockWallpaperStore: WallpaperStoring {
    private(set) var photos: [UUID: UIImage] = [:]
    private var order: [UUID] = []

    func add(_ imageData: Data) async throws -> UUID {
        guard let image = UIImage(data: imageData) else { throw WallpaperStoreError.unreadableImage }
        let id = UUID()
        photos[id] = image
        order.insert(id, at: 0)
        return id
    }
    func image(for id: UUID) async -> UIImage? { photos[id] }
    func photoIDs() -> [UUID] { order }
    func delete(_ id: UUID) {
        photos[id] = nil
        order.removeAll { $0 == id }
    }
}
