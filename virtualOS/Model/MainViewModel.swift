//
//  MainViewModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit
import AVFoundation // for microphone support
import OSLog

#if arch(arm64)

final class MainViewModel {
    let tableViewDataSource      = TableViewDataSource()
    let parametersViewDataSource = ParametersViewDataSource()
    let parametersViewDelegate   = ParametersViewDelegate()
    let textFieldDelegate        = TextFieldDelegate()
    var vmBundle: VMBundle?
    var selectedRow: Int? = 0
    var vmParameters: VMParameters?
    
    init() {
        parametersViewDataSource.mainViewModel = self
    }
    
    func storeParametersToDisk() {
        if let vmParameters = vmParameters,
           let vmBundleUrl = vmBundle?.url
        {
            vmParameters.writeToDisk(bundleURL: vmBundleUrl)
        }
    }

    func deleteVM(selection: NSApplication.ModalResponse, vmBundle: VMBundle) {
        try? FileManager.default.removeItem(at: vmBundle.url)
        if let selectedRow,
           selectedRow > tableViewDataSource.rows() - 1
        {
            self.selectedRow = tableViewDataSource.rows() - 1 // select last table row
        }
    }
    
    func set(sharedFolderUrl: URL?) {
        var sharedFolderData: Data? = nil

        if let sharedFolderUrl {
            sharedFolderData = Bookmark.createBookmarkData(fromUrl: sharedFolderUrl)
            if let sharedFolderData {
                _ = Bookmark.startAccess(bookmarkData: sharedFolderData, for: sharedFolderUrl.path)
                
                if let selectedRow {
                    let bundle = tableViewDataSource.vmBundle(forRow: selectedRow)
                    if let bundleURL = bundle?.url {
                        var vmParameters = VMParameters.readFrom(url: bundleURL)
                        vmParameters?.sharedFolderURL  = sharedFolderUrl
                        vmParameters?.sharedFolderData = sharedFolderData
                        vmParameters?.writeToDisk(bundleURL: bundleURL)
                        self.vmParameters = vmParameters
                    }
                }
            }
        }
    }
    
    func checkMicrophonePermission(completion: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            // Logger.shared.log(level: .default, "audio support in the vm enabled: \(granted)")
            if !granted {
                self.vmParameters?.microphoneEnabled = false
                self.storeParametersToDisk()
                completion()
            }
        }
    }

}

#endif
