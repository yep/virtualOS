//
//  MenuCommands.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 25.02.23.
//

import SwiftUI

struct MenuCommands: Commands {
    @ObservedObject var viewModel: MainViewModel

    #if arch(arm64)

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
        CommandGroup(replacing: .newItem) {}
        CommandGroup(after: .newItem) {
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
            Button("Enter Full Screen") {
                if let window = NSApplication.shared.windows.first {
                    window.toggleFullScreen(nil)
                }
            }.keyboardShortcut("F", modifiers: [.command, .option])
        }
    }
    
    #endif // #if arch(arm64)
}

