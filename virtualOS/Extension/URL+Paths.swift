//
//  URL+Paths.swift
//  virtualOS
//

import Foundation

extension URL {
    static let basePath             = NSHomeDirectory() + "/Documents"
    static let restoreImageURL      = URL(fileURLWithPath: basePath + "/RestoreImage.ipsw")
    static let bundleName           = "virtualOS.bundle/"
    
    static var baseURL: URL {
        return URL(fileURLWithPath: basePath)
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

