//
//  Data+Bookmark.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 24.03.23.
//

import Foundation

struct Bookmark {
    enum BookmarkType {
        case hardDisk
        case sharedFolder
    }

    fileprivate static var accessedURLs: [BookmarkType: URL] = [:]
    
    static func createBookmarkData(fromUrl url: URL) -> Data? {
        if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, relativeTo: nil) {
            return bookmarkData
        }
        return nil
    }
    
    static func startAccess(data: Data?, forType key: BookmarkType) -> URL? {
        var bookmarkDataIsStale = false
        if let bookmarkData = data,
           let bookmarkURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale),
           !bookmarkDataIsStale
        {
            // stop accessing previous resource
            if let previousURL = accessedURLs[key],
               previousURL != bookmarkURL
            {
                previousURL.stopAccessingSecurityScopedResource()
            }
            
            if accessedURLs[key] != bookmarkURL {
                // resource not already accessed, start access
                _ = bookmarkURL.startAccessingSecurityScopedResource()
                accessedURLs[key] = bookmarkURL
            }
            return bookmarkURL
        }
        
        return nil
    }
    
    static func stopAccess(url: URL, forKey key: BookmarkType) {
        url.stopAccessingSecurityScopedResource()
        Self.accessedURLs[key] = nil
    }
    
    static func stopAllAccess() {
        for (_, accessedURL) in accessedURLs {
            accessedURL.stopAccessingSecurityScopedResource()
        }
        Self.accessedURLs = [:]
    }
}
