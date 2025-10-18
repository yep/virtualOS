//
//  RestoreImageViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit
import Virtualization
import OSLog

#if arch(arm64)

final class RestoreImageViewController: NSViewController {
    let fileModel = FileModel()
    fileprivate var selectedRestoreImage = ""

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var installButton: NSButton!
    @IBOutlet weak var showInFinderButton: NSButton!
    @IBOutlet weak var infoTextField: NSTextField!    
    
    var restoreImages: [String] {
        return fileModel.getRestoreImages()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Bookmark.startRestoreImagesDirectoryAccess()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        NotificationCenter.default
            .addObserver(self, selector: #selector(reloadTable), name: Constants.didChangeAppSettings, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        updateUI()
        
        if tableView.numberOfRows > 0 {
            // select the first item
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            setButtons(enabled: true)
        } else {
            setButtons(enabled: false)
        }
    }
    
    @IBAction func installButtonPressed(_ sender: NSButton) {
        if tableView.selectedRow != -1 {
            let notification = Notification(name: Constants.restoreImageNameSelectedNotification, userInfo: [Constants.selectedRestoreImage: self.selectedRestoreImage])
            NotificationCenter.default.post(notification)
            view.window?.close()
        }
    }
    
    @IBAction func showInFinderButtonPressed(_ sender: NSButton) {
        if tableView.selectedRow != -1 {
            let url = URL.baseURL.appendingPathComponent(self.selectedRestoreImage)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    @IBAction func downloadLatestButtonPressed(_ sender: NSButton) {
        let notification = Notification(name: Constants.restoreImageNameSelectedNotification, userInfo: [Constants.selectedRestoreImage: Constants.restoreImageNameLatest])
        NotificationCenter.default.post(notification)
        view.window?.close()
    }
    
    @objc private func reloadTable() {
        tableView.reloadData()
    }
    
    fileprivate func updateUI() {
        let restoreImageCount = restoreImages.count
        if restoreImageCount == 0 {
            infoTextField.stringValue = "No restore image available, download latest image."
        } else if tableView.selectedRow < restoreImageCount &&
            tableView.selectedRow != -1
        {
            infoTextField.stringValue = "Loading image..."
            
            let name = restoreImages[tableView.selectedRow]
            let url = URL.restoreImagesDirectoryURL.appendingPathComponent(name)
            VZMacOSRestoreImage.load(from: url) { result in
                DispatchQueue.main.async { [weak self] in
                    var info = ""
                    switch result {
                    case .success(let restoreImage):
                        info = restoreImage.operatingSystemVersionString
                        self?.setButtons(enabled: true)
                    case .failure(let error):
                        info = "Invalid image"
                        self?.setButtons(enabled: false)
                        Logger.shared.log(level: .default, "\(error)")
                    }
                    self?.infoTextField.stringValue = info
                }
            }
        } else {
            infoTextField.stringValue = ""
            setButtons(enabled: false)
        }
    }
    
    fileprivate func setButtons(enabled: Bool) {
        installButton.isEnabled      = enabled
        showInFinderButton.isEnabled = enabled
    }
}

extension RestoreImageViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return restoreImages.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if row < restoreImages.count {
            return restoreImages[row]
        } else {
            return "Unknown"
        }
    }
}

extension RestoreImageViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {        
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 && selectedRow < restoreImages.count {
            selectedRestoreImage = restoreImages[selectedRow]
        }
        
        updateUI()
    }
}

#endif
