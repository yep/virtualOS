//
//  ParametersViewDataSource.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

#if arch(arm64)

final class ParametersViewDataSource: NSObject, NSOutlineViewDataSource {
    weak var mainViewModel: MainViewModel?
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if mainViewModel?.vmParameters != nil {
            return 5
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let vmParameters = mainViewModel?.vmParameters {
            switch index {
            case 0:
                return ["CPU Count", "\(vmParameters.cpuCount)"]
            case 1:
                return ["Memory Size (GB)", "\(vmParameters.memorySizeInGB)"]
            case 2:
                return ["Disk Size (GB)", "\(vmParameters.diskSizeInGB)"]
            case 3:
                let sharedFolderString = sharedFolderInfo(vmParameters: vmParameters)
                return ["Shared Folder", sharedFolderString]
            case 4:
                return ["Version", "\(vmParameters.version)"]
            default:
                return ["index \(index)", "value \(index)"]
            }
        }
        
        return ["index \(index)", "value \(index)"]
    }
    
    fileprivate func sharedFolderInfo(vmParameters: VMParameters) -> String {
        if let sharedFolderURL = vmParameters.sharedFolderURL,
           let sharedFolderData = vmParameters.sharedFolderData,
           let bookmarkURL = Bookmark.startAccess(bookmarkData: sharedFolderData, for: sharedFolderURL.absoluteString)
        {
            return bookmarkURL.path()
        }
        return "No shared folder"
    }
}

#endif
