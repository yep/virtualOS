//
//  OsVersion.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import Virtualization

#if arch(arm64)

extension VZMacOSRestoreImage {
    var operatingSystemVersionString: String {
        return "macOS \(operatingSystemVersion.majorVersion).\(operatingSystemVersion.minorVersion).\(operatingSystemVersion.patchVersion) (Build \(buildVersion))"
    }
}

#endif  
