//
//  MainViewModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import AppKit

#if arch(arm64)

final class MainViewModel {
    let tableViewDataSource      = TableViewDataSource()
    let parametersViewDataSource = ParametersViewDataSource()
    let parametersViewDelegate   = ParametersViewDelegate()
    let textFieldDelegate        = TextFieldDelegate()
    var vmBundle: VMBundle?
    var selectedRow: Int? = 0
    var vmParameters: VMParameters?
    
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
    
    func set(sharedFolderUrl: URL?) -> VMParameters? {
        var sharedFolderData: Data? = nil

        if let sharedFolderUrl {
            sharedFolderData = Bookmark.createBookmarkData(fromUrl: sharedFolderUrl)
            if let sharedFolderData {
                _ = Bookmark.startAccess(bookmarkData: sharedFolderData)
            }
        }
        
        if let selectedRow {
            let bundle = tableViewDataSource.vmBundle(forRow: selectedRow)
            if let bundleURL = bundle?.url {
                var vmParameters = VMParameters.readFrom(url: bundleURL)
                vmParameters?.sharedFolder = sharedFolderData
                vmParameters?.writeToDisk(bundleURL: bundleURL)
                self.vmParameters = vmParameters
                return vmParameters
            }
        }
        
        return nil
    }
}

#endif
