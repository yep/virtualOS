//
//  SettingsViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit
import OSLog

final class SettingsViewController: NSViewController {
    @IBOutlet weak var vmFilesURLLabel: NSTextField!
    
    @IBAction func selectFolderButtonPressed(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select"
        let modalResponse = openPanel.runModal()
        
        guard modalResponse == .OK,
           let vmFilesURL = openPanel.url else
        {
            return
        }
        
        let vmFilesPath = vmFilesURL.path(percentEncoded: false)
        if let bookmarkData = Bookmark.createBookmarkData(fromUrl: vmFilesURL),
           Bookmark.startAccess(bookmarkData: bookmarkData, for: vmFilesPath) != nil
        {
            UserDefaults.standard.vmFilesDirectory = vmFilesPath
            UserDefaults.standard.vmFilesDirectoryBookmarkData = bookmarkData
            postNotification()
        } else {
            Logger.shared.log("Could not create or start accessing bookmark \(vmFilesURL.path)")
        }
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        UserDefaults.standard.vmFilesDirectory = nil
        UserDefaults.standard.vmFilesDirectoryBookmarkData = nil
        postNotification()
    }
    
    @IBAction func showInFinderButtonPressed(_ sender: Any) {
        var url: URL
        if let hardDiskDirectoryString = UserDefaults.standard.vmFilesDirectory {
            url = URL(fileURLWithPath: hardDiskDirectoryString)
        } else {
            url = URL.baseURL
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    override func viewWillAppear() {
        updateVMFilesLabel()
    }
    
    fileprivate func updateVMFilesLabel() {
        vmFilesURLLabel.stringValue = "Storing VM files at:\n\(UserDefaults.standard.vmFilesDirectory ?? URL.basePath)"
    }
    
    fileprivate func postNotification() {
        updateVMFilesLabel()
        NotificationCenter.default.post(name: Constants.didChangeVMLocationNotification, object: nil)
    }
}
