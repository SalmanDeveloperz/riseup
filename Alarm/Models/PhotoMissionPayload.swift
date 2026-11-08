//
//  PhotoMissionPayload.swift
//  RiseUp
//
//  LAYER: Model (plain value type, saved inside MissionConfig.dataPayload)
//  WHAT:  What the Photo mission remembers about the registered spot:
//           • fingerprint: Vision's "feature print" (numbers describing what's in the photo)
//           • thumbnail:   a small JPEG, to show the user WHICH spot to photograph
//  DATA:  encoded to `Data` and stored in MissionConfig.dataPayload (external storage).
//
//  CONNECTIONS:
//    ← CREATED BY: MissionPickerViewModel.registerPhoto (Mission Settings → "Take photo")
//    ← READ BY:    PhotoMissionViewModel (compare a new photo), MissionPickerView (thumbnail)
//
//  WHY no new database field: MissionConfig already has `dataPayload` (planned in SchemaV1
//  for exactly this). Packing two values into it as one encoded struct avoids a schema change.
//

import Foundation

nonisolated struct PhotoMissionPayload: Codable, Sendable, Equatable {
    /// Encoded Vision `FeaturePrintObservation` (see VisionPhotoMatcher).
    var fingerprint: Data
    /// Small JPEG (about 300 px) of the registered spot.
    var thumbnail: Data

    /// Struct → Data, for MissionConfig.dataPayload.
    ///
    /// LEARN: `PropertyListEncoder` with `.binary` stores `Data` compactly (JSON would turn
    /// it into much longer base64 text).
    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    /// Data → struct. Returns `nil` for missing or damaged data instead of throwing.
    static func decode(_ data: Data?) -> PhotoMissionPayload? {
        guard let data else { return nil }
        return try? PropertyListDecoder().decode(PhotoMissionPayload.self, from: data)
    }
}
