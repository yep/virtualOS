//
//  UserDefaults+Settings.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 03.07.22.
//

import Foundation

extension UserDefaults {
    fileprivate static let diskSizeKey = "diskSize"
    
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
}
