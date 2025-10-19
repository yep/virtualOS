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
    static var restoreImageURL: URL {
        return fileURL(for: UserDefaults.standard.restoreImagesDirectory)
    }
    static var restoreImagesDirectoryURL: URL {
        return fileURL(for: UserDefaults.standard.restoreImagesDirectory)
    }
    static var vmFilesDirectoryURL: URL {
        return fileURL(for: UserDefaults.standard.vmFilesDirectory)
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
    
    static func nextURL(for url: URL, index i: Int, baseName: String) -> URL {
        // ensure we're working with a directory, not a file
        var directoryURL = url
        if !url.hasDirectoryPath {
            directoryURL = url.deletingLastPathComponent()
        }
        
        let filename = "\(baseName)_\(i).ipsw"
        return directoryURL.appendingPathComponent(filename)
    }
    
    fileprivate static func fileURL(for path: String?) -> URL {
        if let path {
            return URL(fileURLWithPath: path)
        }
        return baseURL // default value
    }

}

