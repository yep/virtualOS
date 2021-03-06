//
//  virtualOSApp.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

import Foundation
import SwiftUI
import OSLog

typealias CompletionHander = (String?) -> Void
typealias ProgressHandler = (Progress) -> Void

@main
struct virtualOSApp: App {
    static let logger = Logger(subsystem: "com.github.yep.virtualOS", category: "main")
    
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
            .sheet(isPresented: $viewModel.showSettings, content: {
                SettingsView(viewModel: viewModel)
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
            CommandGroup(replacing: .appTermination) {
                Button("Quit", action: {
                    exit(1)
                }).keyboardShortcut("Q")
            }
        }
        #endif
    }
    
    static func debugLog(_ message: String) {
        Self.logger.notice("\(message, privacy: .public)")
    }
}
