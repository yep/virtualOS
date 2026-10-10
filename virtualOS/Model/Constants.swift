//
//  Constants.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

struct Constants {
    static let restoreImageNameLatest  = "latest"
    static let selectedRestoreImageKey = "selectedRestoreImageKey"
    static let provisioningInfoKey     = "provisioningInfoKey"
    static let minimumDiskImageSize    = 30
    static let defaultDiskImageSize    = 100
    static let restoreImageNameSelectedNotification = Notification.Name("restoreImageNameSelectedNotification")
    static let guestProvisioningdNotification       = Notification.Name("guestProvisioningdNotification")
    static let didChangeAppSettingsNotification     = Notification.Name("didChangeAppSettingsNotification")
    
    enum NetworkType: String, CaseIterable, Codable {
        case nat
        case bridged
    }
}
