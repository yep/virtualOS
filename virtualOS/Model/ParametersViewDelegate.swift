//
//  ParametersViewDelegate.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

import AppKit

final class ParametersViewDelegate: NSObject, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var string: String
        
        if let identifier = tableColumn?.identifier,
            let array = item as? [String]
        {
            switch identifier.rawValue {
            case "AutomaticTableColumnIdentifier.0":
                string = array[0]
            case "AutomaticTableColumnIdentifier.1":
                string = array[1]
            default:
                string = "default"
                
            }
        } else {
            string = "unknown"
        }
        
        return NSTextField(labelWithString: string)
    }
}
