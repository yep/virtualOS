//
//  UserDefaults+Settings.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

extension UserDefaults {
    fileprivate static let diskSizeKey                  = "diskSize"
    fileprivate static let vmFilesDirectoryKey          = "vmFilesDirectoryKey"
    fileprivate static let vmFilesDirectoryBookmarkDataKey = "vmFilesDirectoryBookmarkData"
    fileprivate static let restoreImagesDirectoryKey     = "restoreImagesDirectoryKey"
    fileprivate static let restoreImagesDirectoryBookmarkDataKey = "restoreImagesDirectoryBookmarkData"

    var diskSize: Int {
        get {
            if object(forKey: Self.diskSizeKey) != nil {
                return integer(forKey: Self.diskSizeKey)
            }
            return Constants.defaultDiskImageSize
        }
        set {
            set(newValue, forKey: Self.diskSizeKey)
            synchronize()
        }
    }
    
    var vmFilesDirectory: String? {
        get {
            return string(forKey: Self.vmFilesDirectoryKey)
        }
        set {
            set(newValue, forKey: Self.vmFilesDirectoryKey)
            synchronize()
        }
    }

    var vmFilesDirectoryBookmarkData: Data? {
        get {
            return data(forKey: Self.vmFilesDirectoryBookmarkDataKey)
        }
        set {
            set(newValue, forKey: Self.vmFilesDirectoryBookmarkDataKey)
            synchronize()
        }
    }

    /// Returns the Restore Images directory selected by the user
    var restoreImagesDirectory: String? {
        get {
            return string(forKey: Self.restoreImagesDirectoryKey)
        }
        set {
            set(newValue, forKey: Self.restoreImagesDirectoryKey)
            synchronize()
        }
    }

    var restoreImagesDirectoryBookmarkData: Data? {
        get {
            return data(forKey: Self.restoreImagesDirectoryBookmarkDataKey)
        }
        set {
            set(newValue, forKey: Self.restoreImagesDirectoryBookmarkDataKey)
            synchronize()
        }
    }
    
    func resetVMFilesDirectory() {
        UserDefaults.standard.vmFilesDirectory = URL.baseURL.path
        UserDefaults.standard.vmFilesDirectoryBookmarkData = Bookmark.createBookmarkData(fromUrl: URL.baseURL)        
    }
}
