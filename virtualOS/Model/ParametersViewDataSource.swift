//
//  ParametersViewDataSource.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

import AppKit

#if arch(arm64)

final class ParametersViewDataSource: NSObject, NSOutlineViewDataSource {
    var vmParameters: VMParameters?
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if vmParameters != nil {
            return 5
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let vmParameters = vmParameters {
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
        if let sharedFolderData = vmParameters.sharedFolder {
            if let sharedFolderURL = Bookmark.startAccess(bookmarkData: sharedFolderData) {
                return sharedFolderURL.path()
            }
        }
        return "No shared folder"
    }
}

#endif
