//
//  URL+Paths.swift
//  virtualOS
//

import Foundation

extension URL {
    static let basePath         = NSHomeDirectory() + "/Documents"
    static let bundleName       = "virtualOS.bundle/"
    static let restoreImageName = "RestoreImage.ipsw"

    static var baseURL: URL {
        return URL(fileURLWithPath: basePath)
    }
    static var defaultRestoreImageURL: URL {
        return URL(fileURLWithPath: basePath + "/" + restoreImageName)
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
    var machineIdentifierURL: URL {
        return self.appending(path: "MachineIdentifier")
    }
    var parametersURL: URL {
        return self.appending(path: "Parameters.txt")
    }
}

