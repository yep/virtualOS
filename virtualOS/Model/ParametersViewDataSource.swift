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
        if let vmParameters = mainViewModel?.vmParameters {
            if vmParameters.installFinished == true {
                return 4
            } else {
                return 1
            }
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let vmParameters = mainViewModel?.vmParameters {
            if vmParameters.installFinished == false {
                return ["Install incomplete", "Delete this VM and reinstall."]
            } else {
                if index == 0 {
                    return ["Disk Size (GB)", "\(vmParameters.diskSizeInGB)"]
                } else if index == 1 {
                    let sharedFolderString = sharedFolderInfo(vmParameters: vmParameters)
                    return ["Shared Folder", sharedFolderString]
                } else if index == 2 {
                    return ["Version", "\(vmParameters.version)"]
                } else if index == 3 {
                    return ["Snapshots", snapshotInfo()]
                }
            }
            
        }
        
        return ["index \(index)", "value \(index)"]
    }
    
    fileprivate func sharedFolderInfo(vmParameters: VMParameters) -> String {
        if let sharedFolderURL = vmParameters.sharedFolderURL,
           let sharedFolderData = vmParameters.sharedFolderData,
           let bookmarkURL = Bookmark.startAccess(bookmarkData: sharedFolderData, for: sharedFolderURL.path),
           let bookmarkPath = bookmarkURL.path.removingPercentEncoding
        {
            return bookmarkPath
        }
        return "No shared folder"
    }

    fileprivate func snapshotInfo() -> String {
        guard #available(macOS 27.0, *),
              let bundleURL = mainViewModel?.vmBundle?.url,
              SnapshotModel.isSnapshotCapable(bundleURL: bundleURL) else
        {
            return "Not Supported"
        }
        guard let snapshots = try? SnapshotModel(bundleURL: bundleURL).snapshots() else {
            return "None"
        }
        return snapshots.isEmpty ? "None" : "\(snapshots.count)"
    }
}

#endif
