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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        updateInfoLabel()
        if tableView.numberOfRows > 0 {
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
    
    fileprivate func updateInfoLabel() {
        let restoreImageCount = fileModel.getRestoreImages().count
        if restoreImageCount == 0 {
            infoTextField.stringValue = "No restore image available, download latest image."
        } else if tableView.selectedRow < restoreImageCount &&
            tableView.selectedRow != -1
        {
            let name = fileModel.getRestoreImages()[tableView.selectedRow]
            let url = URL.baseURL.appendingPathComponent(name)
            VZMacOSRestoreImage.load(from: url) { result in
                switch result {
                case .success(let restoreImage):
                    DispatchQueue.main.async { [weak self] in
                        self?.infoTextField.stringValue = restoreImage.operatingSystemVersionString
                    }
                case .failure(let error):
                    Logger.shared.log(level: .default, "\(error)")
                }
            }
        } else {
            infoTextField.stringValue = ""
        }
    }
    
    fileprivate func setButtons(enabled: Bool) {
        installButton.isEnabled      = enabled
        showInFinderButton.isEnabled = enabled
    }
}

extension RestoreImageViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return fileModel.getRestoreImages().count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let restoreImages = fileModel.getRestoreImages()
        if row < restoreImages.count {
            return restoreImages[row]
        } else {
            return "Unknown"
        }
    }
}

extension RestoreImageViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let restoreImages = fileModel.getRestoreImages()
        
        let selectedRow = tableView.selectedRow
        if selectedRow != -1 && selectedRow < restoreImages.count {
            selectedRestoreImage = restoreImages[selectedRow]
            setButtons(enabled: true)
        } else {
            setButtons(enabled: false)
        }
        updateInfoLabel()
    }
}

#endif
