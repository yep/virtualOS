//
//  Data+Bookmark.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file..
//

import Foundation
import OSLog

struct Bookmark {    
    fileprivate static var accessedURLs: [String: URL] = [:]

    static func createBookmarkData(fromUrl url: URL) -> Data? {
        if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, relativeTo: nil) {
            return bookmarkData
        }
        return nil
    }
    
    static func startAccess(bookmarkData: Data?, for path: String) -> URL? {
        var bookmarkDataIsStale = false
        if let bookmarkData = bookmarkData,
           let bookmarkURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale),
           !bookmarkDataIsStale
        {
            // stop accessing previous resource
            if let previousURL = accessedURLs[path],
               previousURL != bookmarkURL
            {
                stopAccess(url: previousURL)
            }
            
            if accessedURLs[path] != bookmarkURL {
                // resource not already accessed, start access
                if bookmarkURL.startAccessingSecurityScopedResource() {
                    // Logger.shared.log(level: .info, "start accessing security scoped resource: \(path)")
                } else {
                    // Logger.shared.log(level: .info, "stop accessing security scoped resource failed")
                }
                accessedURLs[path] = bookmarkURL
            }
            return bookmarkURL
        }
        
        return nil
    }
    
    static func stopAccess(url: URL) {
        url.stopAccessingSecurityScopedResource()
        // Logger.shared.log(level: .info, "stop accessing security scoped resource (1): \(url.path)")
        Self.accessedURLs[url.path] = nil
    }
    
    static func stopAllAccess() {
        for (urlString, accessedURL) in accessedURLs {
            accessedURL.stopAccessingSecurityScopedResource()
            Logger.shared.log(level: .info, "stop accessing security scoped resource (2): \(urlString)")
        }
        Self.accessedURLs = [:]
    }
    
    static func startRestoreImagesDirectoryAccess() -> Bool {
        guard let filesDirectoryString = UserDefaults.standard.restoreImagesDirectory ?? UserDefaults.standard.vmFilesDirectory else {
            return false
        }
        
        // grant access
        let bookmarkData = UserDefaults.standard.restoreImagesDirectoryBookmarkData ?? UserDefaults.standard.vmFilesDirectoryBookmarkData
        if Bookmark.startAccess(bookmarkData: bookmarkData, for: filesDirectoryString) == nil {
            return false
        }
        return true
    }
}
