//
//  UserDefaults+Settings.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

extension UserDefaults {
    fileprivate static let diskSizeKey                           = "diskSize"
    fileprivate static let vmFilesDirectoryKey                   = "vmFilesDirectoryKey"
    fileprivate static let vmFilesDirectoryBookmarkDataKey       = "vmFilesDirectoryBookmarkData"
    fileprivate static let restoreImagesDirectoryKey             = "restoreImagesDirectoryKey"
    fileprivate static let restoreImagesDirectoryBookmarkDataKey = "restoreImagesDirectoryBookmarkData"
    fileprivate static let userRatingCounterKey                  = "userRatingCounterKey"

    var diskSize: Int {
        get {
            if object(forKey: Self.diskSizeKey) != nil {
                let diskSize = integer(forKey: Self.diskSizeKey)
                if diskSize < Constants.minimumDiskImageSize {
                    return Constants.minimumDiskImageSize
                } else {
                    return diskSize
                }
            }
            return Constants.defaultDiskImageSize
        }
        set {
            if newValue < Constants.minimumDiskImageSize {
                set(Constants.minimumDiskImageSize, forKey: Self.diskSizeKey)
            } else {
                set(newValue, forKey: Self.diskSizeKey)
            }
            synchronize()
        }
    }
    
    var vmFilesDirectory: String? {
        get {
            if let result = string(forKey: Self.vmFilesDirectoryKey) {
                return result.removingPercentEncoding
            } else {
                return nil
            }
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

    var restoreImagesDirectory: String? {
        get {
            if let result = string(forKey: Self.restoreImagesDirectoryKey) {
                return result.removingPercentEncoding
            } else {
                return nil
            }
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
    
    var userRatingCounter: Int {
        get {
            return integer(forKey: Self.userRatingCounterKey)
        }
        set {
            set(newValue, forKey: Self.userRatingCounterKey)
            synchronize()
        }
    }
}
