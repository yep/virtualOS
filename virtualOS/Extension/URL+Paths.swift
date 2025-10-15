//
//  URL+Paths.swift
//  virtualOS
//

import Foundation

extension URL {
    static let bundleName = "virtualOS.bundle/"
    
    static var documentsPath = NSHomeDirectory() + "/Documents" {
        didSet {
            // TODO: log change
        }
    }
    
    static var defaultRestoreImageURL: URL {
        return self.documentsPathURL.appending(path: "/RestoreImage.ipsw")
    }
    
    static var documentsPathURL: URL {
        return URL(fileURLWithPath: documentsPath)
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

