//
//  AlertController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AppKit

extension NSAlert {
    static func okCancelAlert(messageText: String, informativeText: String, showCancelButton: Bool = true, accessoryView: NSView? = nil, alertStyle: NSAlert.Style = .informational) -> NSAlert {
        let alert: NSAlert = NSAlert()
        
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.accessoryView = accessoryView
        alert.alertStyle = alertStyle
        alert.addButton(withTitle: "OK")
        if showCancelButton {
            alert.addButton(withTitle: "Cancel")
        }
        
        return alert
    }
}
