//
//  Snapshot.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import DiskImageKit
import Foundation

#if arch(arm64)

@available(macOS 27.0, *)
struct SnapshotRecord: Codable, Identifiable, Equatable {
    enum State: String, Codable {
        case creating
        case ready
        case failed
    }

    let id: UUID
    let name: String
    let createdAt: Date
    let layerPath: String
    let parentSnapshotID: UUID?
    let layerUUID: UUID
    let parentUUID: UUID
    var state: State
}

@available(macOS 27.0, *)
struct SnapshotManifest: Codable, Equatable {
    struct ActiveLayer: Codable, Equatable {
        let layerPath: String
        let parentSnapshotID: UUID?
        let layerUUID: UUID
        let parentUUID: UUID
    }

    let version: Int
    let baseImagePath: String
    let baseLayerUUID: UUID
    let blockCount: Int
    let blockSize: Int
    var nextSnapshotNumber: Int
    var activeLayer: ActiveLayer
    var snapshots: [SnapshotRecord]
}

/// Owns the persistent layer graph and keeps the open image alive while Virtualization uses it.
@available(macOS 27.0, *)
final class SnapshotModel {
    private static let mutationLock = NSLock()

    let bundleURL: URL
    private(set) var openedImage: DiskImage?

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    static func isSnapshotCapable(bundleURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: bundleURL.snapshotManifestURL.path)
    }

    static func createBaseImage(bundleURL: URL, sizeInBytes: UInt64) throws -> SnapshotModel {
        let blockSize = 512
        let blockCount = Int(sizeInBytes / UInt64(blockSize))
        guard blockCount > 0 else {
            throw SnapshotDiskImageError.invalidManifest("The requested disk size is zero.")
        }

        let snapshotModel = SnapshotModel(bundleURL: bundleURL)
        let baseURL = bundleURL.snapshotBaseImageURL
        try FileManager.default.createDirectory(at: bundleURL.snapshotDirectoryURL, withIntermediateDirectories: true)
        let baseImage = try DiskImage(creating: .asif(url: baseURL, blockCount: blockCount, blockSize: .bytes512))
        let activeURL = bundleURL.snapshotActiveLayerURL
        let stackedImage = try baseImage.appending(.asifLayer(url: activeURL, type: .overlay))
        let persistedBase = try DiskImage(opening: OpenConfiguration(url: baseURL, mode: .readWrite))
        let persistedActive = try DiskImage(opening: OpenConfiguration(url: activeURL, mode: .readWrite))
        guard let baseUUID = persistedBase.layerUUID,
              let activeUUID = persistedActive.layerUUID,
              let parentUUID = persistedActive.parentUUID else
        {
            throw SnapshotDiskImageError.invalidManifest("DiskImageKit did not provide layer identifiers.")
        }

        let manifest = SnapshotManifest(
            version: 1,
            baseImagePath: baseURL.lastPathComponent,
            baseLayerUUID: baseUUID,
            blockCount: blockCount,
            blockSize: blockSize,
            nextSnapshotNumber: 1,
            activeLayer: .init(
                layerPath: snapshotModel.relativePath(for: activeURL),
                parentSnapshotID: nil,
                layerUUID: activeUUID,
                parentUUID: parentUUID
            ),
            snapshots: []
        )
        try snapshotModel.write(manifest: manifest)
        snapshotModel.openedImage = stackedImage
        return snapshotModel
    }

    func openActiveImage() throws -> DiskImage {
        let manifest = try readManifest()
        let image = try openStack(manifest: manifest, through: manifest.activeLayer.parentSnapshotID, activeLayer: manifest.activeLayer)
        openedImage = image
        return image
    }

    func snapshots() throws -> [SnapshotRecord] {
        try readManifest().snapshots.filter { $0.state == .ready }.sorted { $0.createdAt < $1.createdAt }
    }

    func snapshotName(for snapshotID: UUID) throws -> String? {
        try snapshots().first(where: { $0.id == snapshotID })?.name
    }

    func deletableSnapshotIDs() throws -> Set<UUID> {
        let manifest = try readManifest()
        return Set(manifest.snapshots.compactMap { snapshot in
            guard snapshot.state == .ready,
                  manifest.activeLayer.parentSnapshotID != snapshot.id,
                  !manifest.snapshots.contains(where: { $0.parentSnapshotID == snapshot.id }) else
            {
                return nil
            }
            return snapshot.id
        })
    }

    func createSnapshot() throws -> SnapshotRecord {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        var manifest = try readManifest()
        let previousActive = manifest.activeLayer
        let previousActiveImage = try DiskImage(opening: OpenConfiguration(url: resolvedURL(for: previousActive.layerPath), mode: .readWrite))
        guard let previousActiveUUID = previousActiveImage.layerUUID,
              let previousActiveParentUUID = previousActiveImage.parentUUID else
        {
            throw SnapshotDiskImageError.invalidManifest("The active layer has no identifiers.")
        }
        let snapshotNumber = manifest.nextSnapshotNumber
        manifest.nextSnapshotNumber += 1
        let snapshotURL = bundleURL.snapshotDirectoryURL.appendingPathComponent(String(format: "snapshot-%06d.asif", snapshotNumber))
        let snapshot = SnapshotRecord(
            id: UUID(),
            name: "Snapshot \(snapshotNumber)",
            createdAt: Date(),
            layerPath: relativePath(for: snapshotURL),
            parentSnapshotID: previousActive.parentSnapshotID,
            layerUUID: previousActiveUUID,
            parentUUID: previousActiveParentUUID,
            state: .creating
        )
        manifest.snapshots.append(snapshot)
        try write(manifest: manifest)

        do {
            try FileManager.default.moveItem(at: resolvedURL(for: previousActive.layerPath), to: snapshotURL)
            let image = try openStack(manifest: manifest, through: snapshot.id, activeLayer: nil)
            let activeURL = bundleURL.snapshotActiveLayerURL
            let stackedImage = try image.appending(.asifLayer(url: activeURL, type: .overlay))
            guard let activeImage = stackedImage.layers.last,
                  let activeUUID = activeImage.layerUUID,
                  let parentUUID = activeImage.parentUUID else
            {
                throw SnapshotDiskImageError.invalidManifest("The new active layer has no identifiers.")
            }

            manifest.activeLayer = .init(
                layerPath: relativePath(for: activeURL),
                parentSnapshotID: snapshot.id,
                layerUUID: activeUUID,
                parentUUID: parentUUID
            )
            manifest.snapshots[manifest.snapshots.count - 1].state = .ready
            try write(manifest: manifest)
            openedImage = stackedImage
            return manifest.snapshots[manifest.snapshots.count - 1]
        } catch {
            if !FileManager.default.fileExists(atPath: resolvedURL(for: previousActive.layerPath).path),
               FileManager.default.fileExists(atPath: snapshotURL.path) {
                try? FileManager.default.moveItem(at: snapshotURL, to: resolvedURL(for: previousActive.layerPath))
            }
            manifest.snapshots.removeLast()
            try? write(manifest: manifest)
            throw error
        }
    }

    func restore(snapshotID: UUID) throws {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        var manifest = try readManifest()
        guard manifest.snapshots.contains(where: { $0.id == snapshotID && $0.state == .ready }) else {
            throw SnapshotDiskImageError.snapshotNotFound
        }

        let image = try openStack(manifest: manifest, through: snapshotID, activeLayer: nil)
        let activeURL = bundleURL.snapshotActiveLayerURL
        let temporaryURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("active-restoring.asif")
        let backupURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("active-previous.asif")
        try? FileManager.default.removeItem(at: temporaryURL)
        try? FileManager.default.removeItem(at: backupURL)

        let replacement: SnapshotManifest.ActiveLayer
        do {
            let stackedImage = try image.appending(.asifLayer(url: temporaryURL, type: .overlay))
            guard let activeImage = stackedImage.layers.last,
                  let activeUUID = activeImage.layerUUID,
                  let parentUUID = activeImage.parentUUID else
            {
                throw SnapshotDiskImageError.invalidManifest("The restored active layer has no identifiers.")
            }
            replacement = .init(
                layerPath: relativePath(for: activeURL),
                parentSnapshotID: snapshotID,
                layerUUID: activeUUID,
                parentUUID: parentUUID
            )
        }

        if FileManager.default.fileExists(atPath: activeURL.path) {
            try FileManager.default.moveItem(at: activeURL, to: backupURL)
        }
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: activeURL)
        } catch {
            try? FileManager.default.moveItem(at: backupURL, to: activeURL)
            throw error
        }

        manifest.activeLayer = replacement
        do {
            try write(manifest: manifest)
        } catch {
            try? FileManager.default.removeItem(at: activeURL)
            try? FileManager.default.moveItem(at: backupURL, to: activeURL)
            throw error
        }
        openedImage = try openActiveImage()
    }

    func delete(snapshotID: UUID) throws {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        var manifest = try readManifest()
        guard let index = manifest.snapshots.firstIndex(where: { $0.id == snapshotID }) else {
            throw SnapshotDiskImageError.snapshotNotFound
        }
        guard manifest.activeLayer.parentSnapshotID != snapshotID,
              !manifest.snapshots.contains(where: { $0.parentSnapshotID == snapshotID }) else
        {
            throw SnapshotDiskImageError.snapshotHasDependents
        }

        let snapshot = manifest.snapshots[index]
        let layerURL = resolvedURL(for: snapshot.layerPath)
        let deletionURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("deleting-\(snapshot.id.uuidString).asif")
        try? FileManager.default.removeItem(at: deletionURL)
        try FileManager.default.moveItem(at: layerURL, to: deletionURL)
        manifest.snapshots.remove(at: index)
        do {
            try write(manifest: manifest)
        } catch {
            try? FileManager.default.moveItem(at: deletionURL, to: layerURL)
            throw error
        }
        try? FileManager.default.removeItem(at: deletionURL)
    }

    private func readManifest() throws -> SnapshotManifest {
        guard Self.isSnapshotCapable(bundleURL: bundleURL) else {
            throw SnapshotDiskImageError.unsupportedImage
        }
        try recoverInterruptedOperations()
        let manifest = try JSONDecoder().decode(SnapshotManifest.self, from: Data(contentsOf: bundleURL.snapshotManifestURL))
        guard manifest.version == 1 else {
            throw SnapshotDiskImageError.invalidManifest("Unsupported manifest version.")
        }
        let layerPaths = [manifest.baseImagePath, manifest.activeLayer.layerPath] + manifest.snapshots.map(\.layerPath)
        guard layerPaths.allSatisfy(isSafeRelativePath),
              Set(layerPaths).count == layerPaths.count else
        {
            throw SnapshotDiskImageError.invalidManifest("A layer path is unsafe or duplicated.")
        }
        guard layerPaths.allSatisfy({ FileManager.default.fileExists(atPath: resolvedURL(for: $0).path) }) else {
            throw SnapshotDiskImageError.invalidManifest("A referenced layer file is missing.")
        }
        return manifest
    }

    /// Restores the manifest's last committed active layer after an interrupted mutation.
    private func recoverInterruptedOperations() throws {
        let manifestURL = bundleURL.snapshotManifestURL
        let manifest = try JSONDecoder().decode(SnapshotManifest.self, from: Data(contentsOf: manifestURL))
        guard isSafeRelativePath(manifest.activeLayer.layerPath) else {
            throw SnapshotDiskImageError.invalidManifest("The active layer path is unsafe.")
        }

        var repairedManifest = manifest
        let activeURL = resolvedURL(for: manifest.activeLayer.layerPath)
        for snapshot in manifest.snapshots where snapshot.state == .creating {
            guard isSafeRelativePath(snapshot.layerPath) else {
                throw SnapshotDiskImageError.invalidManifest("A pending snapshot layer path is unsafe.")
            }
            let snapshotURL = resolvedURL(for: snapshot.layerPath)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                try? FileManager.default.removeItem(at: activeURL)
                try FileManager.default.moveItem(at: snapshotURL, to: activeURL)
            } else if !FileManager.default.fileExists(atPath: activeURL.path) {
                throw SnapshotDiskImageError.invalidManifest("An interrupted snapshot has no recoverable active layer.")
            }
            repairedManifest.snapshots.removeAll { $0.id == snapshot.id }
        }

        for snapshot in repairedManifest.snapshots {
            let layerURL = resolvedURL(for: snapshot.layerPath)
            let deletionURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("deleting-\(snapshot.id.uuidString).asif")
            guard FileManager.default.fileExists(atPath: deletionURL.path) else { continue }
            if FileManager.default.fileExists(atPath: layerURL.path) {
                try? FileManager.default.removeItem(at: deletionURL)
            } else {
                try FileManager.default.moveItem(at: deletionURL, to: layerURL)
            }
        }

        let backupURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("active-previous.asif")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            let activeImage = try? DiskImage(opening: OpenConfiguration(url: activeURL, mode: .readWrite))
            if activeImage?.layerUUID == repairedManifest.activeLayer.layerUUID {
                try? FileManager.default.removeItem(at: backupURL)
            } else {
                try? FileManager.default.removeItem(at: activeURL)
                try FileManager.default.moveItem(at: backupURL, to: activeURL)
            }
        }

        let temporaryURL = bundleURL.snapshotDirectoryURL.appendingPathComponent("active-restoring.asif")
        try? FileManager.default.removeItem(at: temporaryURL)
        if let files = try? FileManager.default.contentsOfDirectory(at: bundleURL.snapshotDirectoryURL, includingPropertiesForKeys: nil) {
            let pendingDeletionNames = Set(repairedManifest.snapshots.map { "deleting-\($0.id.uuidString).asif" })
            for file in files where file.lastPathComponent.hasPrefix("deleting-") && !pendingDeletionNames.contains(file.lastPathComponent) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        if repairedManifest != manifest {
            try write(manifest: repairedManifest)
        }
    }

    private func write(manifest: SnapshotManifest) throws {
        try FileManager.default.createDirectory(at: bundleURL.snapshotDirectoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(manifest)
        let temporaryURL = bundleURL.snapshotManifestURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)
        if FileManager.default.fileExists(atPath: bundleURL.snapshotManifestURL.path) {
            _ = try FileManager.default.replaceItemAt(bundleURL.snapshotManifestURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: bundleURL.snapshotManifestURL)
        }
    }

    private func openStack(manifest: SnapshotManifest, through snapshotID: UUID?, activeLayer: SnapshotManifest.ActiveLayer?) throws -> DiskImage {
        let baseURL = resolvedURL(for: manifest.baseImagePath)
        var image = try DiskImage(opening: OpenConfiguration(url: baseURL, mode: .readWrite))
        guard image.format == .asif,
              image.layerUUID == manifest.baseLayerUUID,
              image.blockCount == manifest.blockCount,
              image.size == manifest.blockCount * manifest.blockSize else
        {
            throw SnapshotDiskImageError.invalidManifest("The base image does not match the manifest.")
        }

        let layers = try lineage(in: manifest, through: snapshotID)
        var expectedParentUUID = manifest.baseLayerUUID
        for layer in layers {
            let nextImage = try DiskImage(opening: OpenConfiguration(url: resolvedURL(for: layer.layerPath), mode: .readWrite))
            guard nextImage.parentUUID == expectedParentUUID,
                  nextImage.blockCount == manifest.blockCount else
            {
                throw SnapshotDiskImageError.invalidManifest("A snapshot layer does not match its parent.")
            }
            image = try image.appending(nextImage)
            guard let layerUUID = nextImage.layerUUID else {
                throw SnapshotDiskImageError.invalidManifest("A snapshot layer has no identifier.")
            }
            expectedParentUUID = layerUUID
        }

        if let activeLayer {
            let nextImage = try DiskImage(opening: OpenConfiguration(url: resolvedURL(for: activeLayer.layerPath), mode: .readWrite))
            guard nextImage.parentUUID == expectedParentUUID,
                  nextImage.blockCount == manifest.blockCount else
            {
                throw SnapshotDiskImageError.invalidManifest("The active layer does not match its parent.")
            }
            image = try image.appending(nextImage)
        }
        return image
    }

    private func lineage(in manifest: SnapshotManifest, through snapshotID: UUID?) throws -> [SnapshotRecord] {
        guard let snapshotID else { return [] }
        var snapshotByID = Dictionary(uniqueKeysWithValues: manifest.snapshots.map { ($0.id, $0) })
        var result: [SnapshotRecord] = []
        var nextID: UUID? = snapshotID
        while let id = nextID {
            guard let snapshot = snapshotByID.removeValue(forKey: id), snapshot.state == .ready || id == snapshotID else {
                throw SnapshotDiskImageError.invalidManifest("A snapshot parent is missing or incomplete.")
            }
            result.append(snapshot)
            nextID = snapshot.parentSnapshotID
        }
        return result.reversed()
    }

    private func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: bundleURL.path + "/", with: "")
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        return !path.isEmpty &&
               !path.hasPrefix("/") &&
               !path.split(separator: "/").contains("..")
    }

    private func resolvedURL(for relativePath: String) -> URL {
        let url = bundleURL.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(bundleURL.standardizedFileURL.path + "/") else {
            // Manifest paths are untrusted persisted input and must not escape the bundle.
            return bundleURL.appendingPathComponent("InvalidSnapshotPath")
        }
        return url
    }
}

#endif
