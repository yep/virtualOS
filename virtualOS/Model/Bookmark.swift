//
//  Data+Bookmark.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 24.03.23.
//

import Foundation
import OSLog

struct Bookmark {
    fileprivate static let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")
    fileprivate static var currentlyAccessedUrl: URL?
    
    static func createBookmarkData(fromUrl url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, relativeTo: nil)
            return bookmarkData
        } catch let error {
            Self.logger.log(level: .default, "error creating bookmark: \(error.localizedDescription)")
        }
        return nil
    }
    
    static func startAccess(bookmarkData: Data?) -> URL? {
        if let currentlyAccessedUrl = Self.currentlyAccessedUrl {
            // stop previous access
            currentlyAccessedUrl.stopAccessingSecurityScopedResource()
        }
        
        var bookmarkDataIsStale = false
        if let bookmarkData,
           let bookmarkURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale),
           !bookmarkDataIsStale
        {
            _ = bookmarkURL.startAccessingSecurityScopedResource()
            Self.currentlyAccessedUrl = bookmarkURL
            return bookmarkURL
        }
        
        return nil
    }
}
