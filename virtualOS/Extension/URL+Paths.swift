//
//  URL+Paths.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

extension URL {
    static let basePath = NSHomeDirectory() + "/Documents"

    static var baseURL: URL {
        return URL(fileURLWithPath: basePath)
    }
    static var restoreImageURL: URL {
        return fileURL(for: UserDefaults.standard.restoreImagesDirectory)
    }
    static var restoreImagesDirectoryURL: URL {
        return fileURL(for: UserDefaults.standard.restoreImagesDirectory)
    }
    static var vmFilesDirectoryURL: URL {
        return fileURL(for: UserDefaults.standard.vmFilesDirectory)
    }
    static var tmpURL: URL {
        return URL(fileURLWithPath: NSHomeDirectory() + "/tmp")
    }
    
    var auxiliaryStorageURL: URL {
        return self.appending(path: "AuxiliaryStorage")
    }
    var hardwareModelURL: URL {
        return self.appending(path: "HardwareModel")
    }
    var diskImageURL: URL {
        return self.appending(path: "Disk.img")
    }
    var snapshotBaseImageURL: URL {
        return self.appending(path: "Disk.asif")
    }
    var snapshotDirectoryURL: URL {
        return self.appending(path: "Snapshots", directoryHint: .isDirectory)
    }
    var snapshotActiveLayerURL: URL {
        return snapshotDirectoryURL.appending(path: "active.asif")
    }
    var snapshotManifestURL: URL {
        return self.appending(path: "Snapshots.json")
    }
    var machineIdentifierURL: URL {
        return self.appending(path: "MachineIdentifier")
    }
    var parametersURL: URL {
        return self.appending(path: "Parameters.txt")
    }
    
    /// Start accessing security scoped URL for the VM files directory.
    /// - Returns: VM files directory URL or default value
    static func startAccessingVMFilesDirectory() -> URL {
        if let bookmarkPath = UserDefaults.standard.vmFilesDirectory?.removingPercentEncoding,
           let bookmarkData = UserDefaults.standard.vmFilesDirectoryBookmarkData
        {
            if let directoryURL = Bookmark.startAccess(bookmarkData: bookmarkData, for: bookmarkPath) {
                return directoryURL
            } else {
                // previous vm file directory no longer exists, reset to default
                UserDefaults.standard.vmFilesDirectory = URL.basePath
                return URL.baseURL
            }
        }
        return URL.baseURL // default
    }
    
    /// Start accessing security scoped URL for the restore images directory.
    /// - Returns: Restore image directory URL or default value
    static func startAccessingRestoreImagesDirectory() -> URL {
        if let bookmarkPath = UserDefaults.standard.restoreImagesDirectory?.removingPercentEncoding,
           let bookmarkData = UserDefaults.standard.restoreImagesDirectoryBookmarkData
        {
            if Bookmark.startAccess(bookmarkData: bookmarkData, for: bookmarkPath) == nil {
                // previous restore image directory no longer exists, reset
                UserDefaults.standard.restoreImagesDirectory = URL.basePath
                return URL.baseURL
            }
            return URL.restoreImageURL
        }
        return URL.baseURL // default
    }
    
    fileprivate static func fileURL(for path: String?) -> URL {
        if let path {
            return URL(fileURLWithPath: path)
        }
        return baseURL // default value
    }

    /// Try to find a filename that does not exist
    ///  - Returns: URL of the created filename
    static func createFilename(baseURL: URL, name: String, suffix: String) -> URL {
        var url = baseURL.appendingPathComponent("\(name).\(suffix)")
        var i = 1
        var exists = true
        
        while exists {
            if FileManager.default.fileExists(atPath: url.path) {
                url = baseURL.appendingPathComponent("\(name)_\(i).\(suffix)")
                i += 1
            } else {
                exists = false
            }
        }
        return url
    }

}
