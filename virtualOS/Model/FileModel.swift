//
//  FileModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

import Foundation

struct FileModel {
    var bundleExists: Bool {
        return FileManager.default.fileExists(atPath: URL.vmBundleURL.path())
    }
    
    var restoreImageExists: Bool {
        return FileManager.default.fileExists(atPath: URL.restoreImageURL.path)
    }

    func getVMBundles() -> [VMBundle] {
        var result: [VMBundle] = []
        if let urls = try? FileManager.default.contentsOfDirectory(at: URL.baseURL, includingPropertiesForKeys: nil, options: []) {
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
        
        if let urls = try? FileManager.default.contentsOfDirectory(at: URL.baseURL, includingPropertiesForKeys: nil, options: []) {
            for url in urls {
                if url.lastPathComponent.hasSuffix("ipsw") {
                    result.append(url.lastPathComponent)
                }
            }
        }
        return result
    }

}
