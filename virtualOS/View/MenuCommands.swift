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
            Button("Delete Restore Image", action: {
                viewModel.deleteRestoreImage()
            }).disabled(!MainViewModel.restoreImageExists)
            Button("Delete Virtual Machine", action: {
                viewModel.deleteVirtualMachine()
            })
        }
    }
    
    #endif // #if arch(arm64)
}

