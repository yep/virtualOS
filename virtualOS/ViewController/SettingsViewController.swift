//
//  SettingsViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit
import OSLog

fileprivate enum SettingTag: Int {
    case vmFilesDirectory
    case restoreImagesDirectory
}

final class SettingsViewController: NSViewController {
    @IBOutlet weak var vmFilesURLLabel: NSTextField!
    @IBOutlet weak var restoreImageFilesURLLabel: NSTextField!
    
    override func viewWillAppear() {
        super.viewWillAppear()        
        updateSettingsLabels()
    }
    
    @IBAction func selectFolderButtonPressed(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select Folder"
        let modalResponse = openPanel.runModal()
        
        guard modalResponse == .OK,
           let selectedURL = openPanel.url else
        {
            return
        }
        
        let selectedPath = selectedURL.path(percentEncoded: false)
        
        guard let bookmarkData = Bookmark.createBookmarkData(fromUrl: selectedURL),
              Bookmark.startAccess(bookmarkData: bookmarkData, for: selectedPath) != nil else
        {
            Logger.shared.log("Could not create or start accessing bookmark \(selectedURL.path)")
            return
        }
        
        switch SettingTag(rawValue: sender.tag) {
        case .vmFilesDirectory:
            UserDefaults.standard.vmFilesDirectory = selectedPath
            UserDefaults.standard.vmFilesDirectoryBookmarkData = bookmarkData
        case .restoreImagesDirectory:
            UserDefaults.standard.restoreImagesDirectory = selectedPath
            UserDefaults.standard.restoreImagesDirectoryBookmarkData = bookmarkData
        default:
            Logger.shared.log("Invalid setting tag")
        }
        
        postNotification()
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        UserDefaults.standard.vmFilesDirectory = nil
        UserDefaults.standard.vmFilesDirectoryBookmarkData = nil
        
        UserDefaults.standard.restoreImagesDirectory = nil
        UserDefaults.standard.restoreImagesDirectoryBookmarkData = nil
        
        postNotification()
    }
    
    @IBAction func showInFinderButtonPressed(_ sender: NSButton) {
        var url = URL.baseURL
        
        switch SettingTag(rawValue: sender.tag) {
        case .vmFilesDirectory:
            url = URL.vmFilesDirectoryURL
        case .restoreImagesDirectory:
            url = URL.restoreImagesDirectoryURL
        default:
            Logger.shared.log("Invalid setting tag")
        }
        
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    fileprivate func updateSettingsLabels() {
        let vmFilesDirectory = FileModel.createVMFilesDirectory()
        restoreImageFilesURLLabel.stringValue = UserDefaults.standard.restoreImagesDirectory ?? vmFilesDirectory.path
        vmFilesURLLabel.stringValue = vmFilesDirectory.path
    }
    
    fileprivate func postNotification() {
        updateSettingsLabels()
        NotificationCenter.default.post(name: Constants.didChangeAppSettingsNotification, object: nil)
    }
}
