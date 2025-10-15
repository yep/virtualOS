//
//  WindowController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Cocoa
import OSLog

#if arch(arm64)

class WindowController: NSWindowController {
    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var installButton: NSToolbarItem!
    @IBOutlet weak var startButton: NSToolbarItem!
    @IBOutlet weak var sharedFolderButton: NSToolbarItem!
    @IBOutlet weak var deleteButton: NSToolbarItem!
    
    weak var mainViewController: MainViewController?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        toolbar.allowsUserCustomization = false
    }
            
    @IBAction func installButtonPressed(_ sender: NSButton) {
        mainViewController?.installButtonPressed(sender)
    }
    
    @IBAction func startButtonPressed(_ sender: NSButton) {
        mainViewController?.startButtonPressed(sender)
    }
    
    @IBAction func sharedFolderButtonPressed(_ sender: NSButton) {
        mainViewController?.sharedFolderButtonPressed(sender)
    }
    
    @IBAction func deleteButtonPressed(_ sender: NSButton) {
        mainViewController?.deleteButtonPressed(sender)
    }
    
    func updateButtons(hidden: Bool) {
        if hidden {
            while toolbar.items.count > 1 {
                toolbar.removeItem(at: 1)
            }
        } else if toolbar.items.count == 1 {
            toolbar.insertItem(withItemIdentifier: startButton.itemIdentifier, at: 1)
            toolbar.insertItem(withItemIdentifier: sharedFolderButton.itemIdentifier, at: 2)
            toolbar.insertItem(withItemIdentifier: deleteButton.itemIdentifier, at: 3)
        }
    }
}

#endif
