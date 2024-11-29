//
//  TableViewDataSource.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

final class TableViewDataSource: NSObject, NSTableViewDataSource {
    fileprivate let fileModel = FileModel()
    
    func rows() -> Int {
        return fileModel.getVMBundles().count
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return fileModel.getVMBundles().count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return vmBundle(forRow: row)?.name
    }
    
    func vmBundle(forRow row: Int) -> VMBundle? {
        let bundles = fileModel.getVMBundles()
        if 0 <= row && row < bundles.count {
            return bundles[row]
        } else {
            return nil
        }
    }
}

