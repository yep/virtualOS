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
    
    enum HardDiskLocation: String, CaseIterable, Identifiable {
        case sandbox = "Sandbox"
        case custom = "Select location where VM hard disk images will be stored."
        var id: Self { self }
    }
    enum RestoreImageType: String, CaseIterable, Identifiable {
        case latest = "Downloads latest restore image from Apple."
        case custom = "Select custom restore image (.ipsw)\nFor example, download from [https://ipsw.me](https://ipsw.me/product/Mac)"
        var id: Self { self }
    }
    
    @State var diskSize = String(UserDefaults.standard.diskSize)
    @State var hardDisk = HardDiskLocation.sandbox
    @State var restoreImageType = RestoreImageType.latest
    
    var hardDiskLocationInfo: String {
        if let customHardDiskURL = viewModel.customHardDiskURL {
            return "Using \(customHardDiskURL.path)"
        } else if hardDisk == .sandbox {
            return URL.basePath
        } else {
            return HardDiskLocation.custom.rawValue
        }
    }
    var restoreImageInfo: String {
        if let restoreImageURL = viewModel.customRestoreImageURL {
            return "Using \(restoreImageURL.path)"
        } else {
            return restoreImageType.rawValue
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
                
                Picker("Hard Disk Location:", selection: $hardDisk) {
                    Text("Default").tag(HardDiskLocation.sandbox)
                    Text("Custom").tag(HardDiskLocation.custom)
                }
                .pickerStyle(.inline)
                .onChange(of: hardDisk) { newValue in
                    if newValue == .sandbox {
                        UserDefaults.standard.hardDiskDirectoryBookmarkData = nil
                    }
                }

                HStack {
                    Button("Select Hard Disk Location") {
                        selectCustomHardDiskLocation()
                    }.disabled(hardDisk == .sandbox)
                }

                Text(.init("hardDiskLocationInfo"))
                    .font(.caption)
                    .frame(maxWidth: 270, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .disabled(hardDisk == .sandbox)
                
                Picker("Restore Image:", selection: $restoreImageType) {
                    Text("Latest").tag(RestoreImageType.latest)
                    Text("Custom").tag(RestoreImageType.custom)
                }.pickerStyle(.inline)
                Button("Select Restore Image") {
                    selectRestoreImage()
                }.disabled(restoreImageType == .latest)
                Text(restoreImageInfo)
                    .font(.caption)
                    .frame(maxWidth: 270, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .disabled(restoreImageType == .latest)
            }.padding(.bottom)

            Text("To open the hard disk location directory:\nIn Finder, in the 'Go' menu, select 'Go to Folder' and enter the path shown above.")
                .frame(maxWidth: 370, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .padding(.bottom)
                .textSelection(.enabled)
                .font(.caption)

            Button("OK") {
                viewModel.showSettings = !viewModel.showSettings
            }.keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(minWidth: 420)
        .onAppear() {
            diskSize = String(viewModel.diskSize)
            if let hardDiskDirectoryBookmarkData = UserDefaults.standard.hardDiskDirectoryBookmarkData,
               let hardDiskURL = Bookmark.startAccess(data: hardDiskDirectoryBookmarkData, forType: .hardDisk)
            {
                hardDisk = .custom
                viewModel.customHardDiskURL = hardDiskURL
            }
        }
    }

    // MARK: - Private

    fileprivate func selectCustomHardDiskLocation() {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: URL.basePath, isDirectory: true)
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        if openPanel.runModal() == .OK,
           let selectedURL = openPanel.url
        {
            let hardDiskDirectoryBookmarkData = Bookmark.createBookmarkData(fromUrl: selectedURL)
            _ = Bookmark.startAccess(data: hardDiskDirectoryBookmarkData, forType: .hardDisk)
            
            viewModel.customHardDiskURL = selectedURL
            UserDefaults.standard.hardDiskDirectoryBookmarkData = hardDiskDirectoryBookmarkData
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

}

struct SettingsViewProvider_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SettingsView(viewModel: MainViewModel())
        }
    }
}

#endif
