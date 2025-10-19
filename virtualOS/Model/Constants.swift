//
//  Constants.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

struct Constants {
    static let restoreImageNameLatest = "latest"
    static let selectedRestoreImage   = "selectedRestoreImage"
    static let restoreImageNameSelectedNotification = Notification.Name("restoreImageSelected")
    static let didChangeAppSettingsNotification   = Notification.Name("didChangeAppSettings")
    static let defaultDiskImageSize   = 30
    
    enum NetworkType: String, CaseIterable, Codable {
        case nat
        case bridged
    }
}
