//
//  UserDefaults+Settings.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 03.07.22.
//

import Foundation

extension UserDefaults {
    fileprivate static let diskSizeKey         = "diskSize"
    fileprivate static let hardDiskBookmarkKey = "hardDiskBookmark"

    var diskSize: Int {
        get {
            if object(forKey: Self.diskSizeKey) != nil {
                return integer(forKey: Self.diskSizeKey)
            }
            return 60 // default value
        }
        set {
            set(newValue, forKey: Self.diskSizeKey)
            synchronize()
        }
    }
    
    var hardDiskDirectoryBookmarkData: Data? {
        get {
            return data(forKey: Self.hardDiskBookmarkKey)
        }
        set {
            set(newValue, forKey: Self.hardDiskBookmarkKey)
            synchronize()
        }
    }
}
