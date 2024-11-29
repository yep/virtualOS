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
    static let vmFilesLocation: String = "virtualOS://files"
    
    fileprivate static var accessedURLs: [String: URL] = [:]

    static func createBookmarkData(fromUrl url: URL) -> Data? {
        if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, relativeTo: nil) {
            return bookmarkData
        }
        return nil
    }
    
    static func startAccess(bookmarkData: Data?, for absoluteURL: String) -> URL? {
        var bookmarkDataIsStale = false
        if let bookmarkData = bookmarkData,
           let bookmarkURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale),
           !bookmarkDataIsStale
        {
            // stop accessing previous resource
            if let previousURL = accessedURLs[absoluteURL],
               previousURL != bookmarkURL
            {
                previousURL.stopAccessingSecurityScopedResource()
            }
            
            if accessedURLs[absoluteURL] != bookmarkURL {
                // resource not already accessed, start access
                _ = bookmarkURL.startAccessingSecurityScopedResource()
                accessedURLs[absoluteURL] = bookmarkURL
            }
            return bookmarkURL
        }
        
        return nil
    }
    
    static func stopAccess(url: URL) {
        url.stopAccessingSecurityScopedResource()
        Self.accessedURLs[url.absoluteString] = nil
    }
    
    static func stopAllAccess() {
        for (_, accessedURL) in accessedURLs {
            accessedURL.stopAccessingSecurityScopedResource()
        }
        Self.accessedURLs = [:]
    }
}
