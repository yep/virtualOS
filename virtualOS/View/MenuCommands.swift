//
//  MenuCommands.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 25.02.23.
//

import SwiftUI

#if arch(arm64)

struct MenuCommands: Commands {
    @ObservedObject var viewModel: MainViewModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About virtualOS") {
                viewModel.showLicenseInformationModal = !viewModel.showLicenseInformationModal
            }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                viewModel.showSettings = !viewModel.showSettings
            }.keyboardShortcut(",")
        }
        CommandGroup(replacing: .newItem) {
            Button(viewModel.statusButtonLabel) {
                viewModel.statusButtonPressed()
            }.keyboardShortcut("R")
            Divider()
            Button("Delete Restore Image") {
                viewModel.deleteRestoreImage()
            }.disabled(!MainViewModel.restoreImageExists)
            Button("Delete Virtual Machine", action: {
                viewModel.deleteVirtualMachine()
            })
        }
        CommandGroup(replacing: .toolbar) {
            let statusBarVisibilityString = viewModel.showStatusBar ? "Hide" : "Show"
            Button(String(format: "%@ Status Bar", statusBarVisibilityString)) {
                viewModel.showStatusBar = !viewModel.showStatusBar
            }.keyboardShortcut("B")
            Divider()
            Button(String(format: "%@ Full Screen", viewModel.isFullScreen ? "Exit" : "Enter")) {
                if let window = NSApplication.shared.windows.first {
                    viewModel.isFullScreen = !viewModel.isFullScreen
                    viewModel.showStatusBar = !viewModel.isFullScreen
                    window.toggleFullScreen(nil)
                }
            }.keyboardShortcut("F")
        }
    }    
}

#endif // #if arch(arm64)
