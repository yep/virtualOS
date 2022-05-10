//
//  virtualOSApp.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

import Foundation
import SwiftUI

func debugLog(_ message: String) {
#if DEBUG
    print(message)
#endif
}

typealias CompletionHander = (String?) -> Void
typealias ProgressHandler = (Progress) -> Void

@main
struct virtualOSApp: App {
    #if arch(arm64)
    @ObservedObject var viewModel = MainViewModel()
    #endif

    var body: some Scene {
        WindowGroup {
            #if arch(arm64)

            MainView(viewModel: viewModel)
            .alert("Delete \(viewModel.confirmationText)", isPresented: $viewModel.showConfirmationAlert) {
                Button("OK") {
                    viewModel.showConfirmationAlert = !viewModel.showConfirmationAlert
                    viewModel.confirmationHandler("")
                }
                Button("Cancel") {
                    viewModel.showConfirmationAlert = !viewModel.showConfirmationAlert
                }
            } message: {
                Text("Are you sure you want to delete the \(viewModel.confirmationText.lowercased())?")
            }
            .alert(viewModel.licenseInformationTitleString, isPresented: $viewModel.showLicenseInformationModal, actions: {}, message: {
                Text(viewModel.licenseInformationString)
            })

            #else
            Text("Sorry, virtualization requires an Apple Silicon computer.")
                .frame(minWidth: 400, minHeight: 300)
            #endif
        }
        #if arch(arm64)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About virtualOS") {
                    viewModel.showLicenseInformationModal = !viewModel.showLicenseInformationModal
                }
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
            CommandGroup(replacing: .appTermination) {
                Button("Quit", action: {
                    exit(1)
                }).keyboardShortcut("Q")
            }
        }
        #endif
    }
}
