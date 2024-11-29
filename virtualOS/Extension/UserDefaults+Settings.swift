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
    fileprivate static let vmFilesDirectoryBookmarkData = "vmFilesDirectoryBookmarkData"

    var diskSize: Int {
        get {
            if object(forKey: Self.diskSizeKey) != nil {
                return integer(forKey: Self.diskSizeKey)
            }
            return 30 // default value
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
            return data(forKey: Self.vmFilesDirectoryBookmarkData)
        }
        set {
            set(newValue, forKey: Self.vmFilesDirectoryBookmarkData)
            synchronize()
        }
    }
}
