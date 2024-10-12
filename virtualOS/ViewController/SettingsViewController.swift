//
//  SettingsViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import AppKit

final class SettingsViewController: NSViewController {
    @IBAction func showInFinderButtonPressed(_ sender: Any) {
        NSWorkspace.shared.activateFileViewerSelecting([URL.baseURL])
    }
}
