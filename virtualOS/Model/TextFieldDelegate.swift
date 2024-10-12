//
//  TextFieldDelegate.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import AppKit

final class TextFieldDelegate: NSObject, NSTextFieldDelegate {
    var vmBundle: VMBundle?
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if let vmBundle = vmBundle,
           vmBundle.name != fieldEditor.string
        {
            let newFilename = "\(fieldEditor.string).bundle"
            let newUrl = vmBundle.url.deletingLastPathComponent().appendingPathComponent(newFilename)
            
            try? FileManager.default.moveItem(at: vmBundle.url, to: newUrl)
        }
        
        return true
    }
}
