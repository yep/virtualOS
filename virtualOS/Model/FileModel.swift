//
//  FileModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

struct FileModel {
    var restoreImageExists: Bool {
        return FileManager.default.fileExists(atPath: URL.defaultRestoreImageURL.path)
    }

    func getVMBundles() -> [VMBundle] {
        var result: [VMBundle] = []
        var hardDiskDirectoryURL: URL
        
        if let hardDiskDirectoryPath = UserDefaults.standard.vmFilesDirectory as String? {
            hardDiskDirectoryURL = URL(fileURLWithPath: hardDiskDirectoryPath)
        } else {
            hardDiskDirectoryURL = URL.documentsPathURL
        }
         
        if let urls = try? FileManager.default.contentsOfDirectory(at: hardDiskDirectoryURL, includingPropertiesForKeys: nil, options: [])
        {
            for url in urls {
                if url.lastPathComponent.hasSuffix("bundle") {
                    result.append(VMBundle(url: url))
                }
            }
        }
        return result
    }
    
    func getRestoreImages() -> [String] {
        var result: [String] = []
        if let urls = try? FileManager.default.contentsOfDirectory(at: URL.documentsPathURL, includingPropertiesForKeys: nil, options: []) {
            for url in urls {
                if url.lastPathComponent.hasSuffix("ipsw") {
                    result.append(url.lastPathComponent)
                }
            }
        }
        return result
    }

}
