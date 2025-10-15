//
//  FileModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation
import OSLog

struct FileModel {
    func getVMBundles() -> [VMBundle] {
        var result: [VMBundle] = []
        var hardDiskDirectoryURL = URL.baseURL
        
        if let hardDiskDirectoryPath = UserDefaults.standard.vmFilesDirectory as String? {
            hardDiskDirectoryURL = URL(fileURLWithPath: hardDiskDirectoryPath)
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
        let vmFilesDirectory = FileModel.createVMFilesDirectory()
                
        if let urls = try? FileManager.default.contentsOfDirectory(at: vmFilesDirectory, includingPropertiesForKeys: nil, options: []) {
            for url in urls {
                if url.lastPathComponent.hasSuffix("ipsw") {
                    result.append(url.lastPathComponent)
                }
            }
        }
        
        return result
    }
    
    static func createVMFilesDirectory() -> URL {
        var url = URL.baseURL
        
        if let vmFilesDirectory = UserDefaults.standard.vmFilesDirectory {
            url = URL(fileURLWithPath: vmFilesDirectory)
        }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        return url
    }
    
    static func cleanUpTemporaryFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: URL.tmpURL, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
        } catch let error {
            Logger.shared.log(level: .default, "error: removing temporary file failed: \(error)")
        }
    }
}
