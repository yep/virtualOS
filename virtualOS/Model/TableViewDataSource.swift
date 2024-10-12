//
//  TableViewDataSource.swift
//  virtualOS
//
//  Created by Jahn Bertsch..
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
        if row < fileModel.getVMBundles().count {
            return fileModel.getVMBundles()[row]
        } else {
            return nil
        }
    }
}

