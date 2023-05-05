//
//  URL+Paths.swift
//  virtualOS
//

import Foundation

extension URL {
    static let basePath             = NSHomeDirectory() + "/Documents"
    static let restoreImageURL      = URL(fileURLWithPath: basePath + "/RestoreImage.ipsw")
    static let bundleName           = "virtualOS.bundle/"
    static let defaultVmBundlePath  = basePath + "/\(bundleName)"
    
    static var vmBundleURL: URL {
        return URL(fileURLWithPath: vmBundlePath)
    }
    static var diskImageURL: URL {
        return URL(fileURLWithPath: vmBundlePath + "/Disk.img")
    }
    static var auxiliaryStorageURL: URL {
        return URL(fileURLWithPath: vmBundlePath + "/AuxiliaryStorage")
    }
    static var machineIdentifierURL: URL {
        return URL(fileURLWithPath: vmBundlePath + "/MachineIdentifier")
    }
    static var hardwareModelURL: URL {
        return URL(fileURLWithPath: vmBundlePath + "/HardwareModel")
    }
    static var parametersURL: URL {
        return URL(fileURLWithPath: vmBundlePath + "/Parameters.txt")
    }

    static var vmBundlePath: String {
        if let hardDiskDirectoryBookmarkData = UserDefaults.standard.hardDiskDirectoryBookmarkData,
           let hardDiskDirectoryURL = Bookmark.startAccess(data: hardDiskDirectoryBookmarkData, forType: .hardDisk)
        {
            let vmBundlePath = hardDiskDirectoryURL.appendingPathComponent(bundleName).path
            return vmBundlePath
        } else {
            return URL.defaultVmBundlePath
        }
    }
}

