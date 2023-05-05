//
//  ApplicationDelegate.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 26.02.23.
//

import AppKit

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Bookmark.stopAllAccess()
    }
}
