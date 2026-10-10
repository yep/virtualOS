//
//  Errors.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

struct RestoreError: Error {
    var localizedDescription = "Restore Error"
}

@available(macOS 27.0, *)
enum SnapshotDiskImageError: LocalizedError {
    case unsupportedImage
    case invalidManifest(String)
    case snapshotHasDependents
    case snapshotNotFound

    var errorDescription: String? {
        switch self {
        case .unsupportedImage:
            return "Snapshots require an ASIF disk image created by virtualOS on macOS 27 or later."
        case .invalidManifest(let reason):
            return "The VM snapshot data is invalid: \(reason)"
        case .snapshotHasDependents:
            return "This snapshot has dependent layers and cannot be deleted."
        case .snapshotNotFound:
            return "The selected snapshot no longer exists."
        }
    }
}
