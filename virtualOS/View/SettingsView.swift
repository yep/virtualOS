//
//  SettingsView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 25.05.22.
//

#if arch(arm64)

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    
    enum RestoreImageType: String {
        case latest = "Downloads latest restore image from Apple."
        case custom = "Select custom restore image (.ipsw)\nFor example, download from [https://ipsw.me](https://ipsw.me/product/Mac)"
    }
    @State var diskSize = String(UserDefaults.standard.diskSize)
    @State var restoreImageType = RestoreImageType.latest
    var restoreImageInfo: String {
        if let restoreImageURL = viewModel.customRestoreImageURL {
            return "Using \(restoreImageURL.path)"
        } else {
            return restoreImageType.rawValue
        }
    }
    
    fileprivate func selectRestoreImage() {
        guard let ipswContentType = UTType(filenameExtension: "ipsw") else {
            return
        }
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [ipswContentType]
        if openPanel.runModal() == .OK,
           let selectedURL = openPanel.url
        {
            viewModel.customRestoreImageURL = selectedURL
        }
    }
    
    var body: some View {
        VStack {
            Text("Settings")
            Form {
                HStack {
                    TextField("Hard Disk Size:", text: $diskSize)
                        .frame(maxWidth: 130)
                        .onChange(of: diskSize) { newValue in
                            if let newDiskSize = Int(diskSize) {
                                viewModel.diskSize = newDiskSize
                            } else {
                                diskSize = ""
                            }
                        }
                    Text("(in GB)")
                }
                
                Picker("Restore Image:", selection: $restoreImageType) {
                    Text("Latest").tag(RestoreImageType.latest)
                    Text("Custom").tag(RestoreImageType.custom)
                }
                .pickerStyle(.inline)

                HStack {
                    Button("Select Restore Image") {
                        selectRestoreImage()
                    }
                    .disabled(restoreImageType == .latest)
                }
                
                Text(.init(restoreImageInfo))
                    .font(.caption)
                    .frame(maxWidth: 270, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .disabled(restoreImageType == .latest)
            }
            .padding(.bottom)

            Text("Virtual machine and restore image location:\n \(URL.basePath)\n\nTo open this directory:\nIn Finder, in the 'Go' menu, select 'Go to Folder' and enter the above URL.")
            .frame(maxWidth: 370, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .padding(.bottom)
            .textSelection(.enabled)
            .font(.caption)

            Button("OK") {
                viewModel.showSettings = !viewModel.showSettings
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(minWidth: 420)
        .onAppear() {
            diskSize = String(viewModel.diskSize)
        }
    }
}

struct SettingsViewProvider_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SettingsView(viewModel: MainViewModel())
        }
    }
}

#endif
