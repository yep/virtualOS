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
    @StateObject var viewModel = ViewModel()
    #endif

    @AppStorage("NSFullScreenMenuItemEverywhere") var fullScreenMenuItemEverywhere = false
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var applicationDelegate

    init() {
        fullScreenMenuItemEverywhere = false
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
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
            
            #endif // #if arch(arm64)
        }
        .commands {
            #if arch(arm64)
            MenuCommands(viewModel: viewModel)
            #endif
        }
    }
    
    static func debugLog(_ message: String) {
        Self.logger.notice("\(message, privacy: .public)")
    }
}
