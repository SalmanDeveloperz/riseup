//
//  PickedMovie.swift
//  RiseUp
//
//  LAYER: Service helper (how a video arrives from the Photos picker)
//  WHAT:  Receives a video the user picked in Photos as a FILE in our temporary folder, so
//         SoundClipMaker can take its sound. The caller deletes the file afterwards.
//  DATA:  tmp/riseup-video-<UUID>.<ext> (deleted by SoundPickerViewModel.addVideo when done)
//
//  CONNECTIONS:
//    ← USED BY: SoundPickerViewModel.addVideo(_:) → `item.loadTransferable(type: PickedMovie.self)`
//
//  WHY a file and not `Data`: a 2-minute video can be hundreds of MB. Loading it as `Data` would put
//  all of it in memory and take seconds. As a file, nothing is read until SoundClipMaker reads just
//  the first seconds of sound.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A video from the Photos library, as a temporary file we may read.
///
/// LEARN: `Transferable` is Apple's way of saying "this type can be made from what the user picked
/// (or dragged, or pasted)". `FileRepresentation` means "hand it to me as a file".
nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            // WHY copy: iOS deletes `received.file` as soon as this closure returns.
            // LEARN: on an iPhone's disk (APFS) a copy within the same disk is a "clone": instant,
            // and it takes no extra space until one of the two files changes.
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("riseup-video-\(UUID().uuidString)")
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
