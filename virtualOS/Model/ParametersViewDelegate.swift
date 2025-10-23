//
//  ParametersViewDelegate.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

final class ParametersViewDelegate: NSObject, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var string = "unknown"
        
        if let identifier = tableColumn?.identifier,
            let array = item as? [String]
        {
            if array.count == 2 {
                switch identifier.rawValue {
                case "AutomaticTableColumnIdentifier.0":
                    string = array[0]
                case "AutomaticTableColumnIdentifier.1":
                    string = array[1]
                default:
                    string = "default"
                    
                }
            } else if array.count == 1 {
                string = array[0]
            }
        }
        
        return NSTextField(labelWithString: string)
    }
}
