//
//  SettingsView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 25.05.22.
//

#if arch(arm64)

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    fileprivate enum HardDiskLocation: String, CaseIterable, Identifiable {
        case sandbox = "Sandbox"
        case custom = "Select location where VM hard disk image will be stored."
        var id: Self { self }
    }
    fileprivate enum RestoreImageType: String, CaseIterable, Identifiable {
        case latest = "Downloads latest restore image from Apple."
        case custom = "Select custom restore image (.ipsw)\nFor example, download from https://ipsw.me/product/mac"
        var id: Self { self }
    }
    fileprivate struct SizeConstants {
        static let totalWidth    = CGFloat(470)
        static let infoWidth     = CGFloat(300)
        static let diskWidth     = CGFloat(140)
        static let locationWidth = CGFloat(450)
        static let minTextHeight = CGFloat(28)
    }
    
    @ObservedObject var viewModel: ViewModel
    @State fileprivate var diskSize = String(UserDefaults.standard.diskSize)
    @State fileprivate var hardDiskLocation = HardDiskLocation.sandbox
    @State fileprivate var restoreImageType = RestoreImageType.latest
    @State fileprivate var showAlert = false

    fileprivate var hardDiskLocationString: String {
        if hardDiskLocation == .sandbox {
            return URL.basePath
        } else {
            if let customHardDiskURL = viewModel.customHardDiskURL {
                return customHardDiskURL.path
            } else {
                return HardDiskLocation.custom.rawValue
            }
        }
    }
    fileprivate var restoreImageInfoString: String {
        if let restoreImageURL = viewModel.customRestoreImageURL {
            return restoreImageURL.path
        } else {
            return restoreImageType.rawValue
        }
    }
    
    var body: some View {
        VStack() {
            Text("Settings").font(.headline)
            Form {
                HStack {
                    TextField("Hard Disk Size:", text: $diskSize)
                        .frame(maxWidth: SizeConstants.diskWidth)
                        .onChange(of: diskSize) { newValue in
                            if let newDiskSize = Int(diskSize) {
                                viewModel.diskSize = newDiskSize
                            } else {
                                diskSize = ""
                            }
                        }
                    Text("(in GB)")
                }
                
                Picker("Hard Disk Location:", selection: $hardDiskLocation) {
                    Text("Default").tag(HardDiskLocation.sandbox)
                    Text("Custom").tag(HardDiskLocation.custom)
                }
                .pickerStyle(.inline)
                .onChange(of: hardDiskLocation) { newValue in
                    if newValue == .sandbox {
                        UserDefaults.standard.hardDiskDirectoryBookmarkData = nil
                    }
                }
                
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: hardDiskLocationString)
                    }.disabled(hardDiskLocation != .sandbox && viewModel.customHardDiskURL == nil)
                    
                    Button("Select Hard Disk Location") {
                        selectCustomHardDiskLocation()
                    }.disabled(hardDiskLocation == .sandbox)
                }

                Text(.init(hardDiskLocationString))
                    .font(.caption)
                    .frame(maxWidth: SizeConstants.infoWidth, minHeight: SizeConstants.minTextHeight, alignment: .topLeading)
                    .lineLimit(nil)
                    .disabled(hardDiskLocation == .sandbox)
                

                Picker("Restore Image:", selection: $restoreImageType) {
                    Text("Latest").tag(RestoreImageType.latest)
                    Text("Custom").tag(RestoreImageType.custom)
                }.pickerStyle(.inline)
                
                Button("Select Restore Image") {
                    selectRestoreImage()
                }.disabled(restoreImageType == .latest)
                
                Text(restoreImageInfoString)
                    .font(.caption)
                    .frame(maxWidth: SizeConstants.infoWidth, minHeight: SizeConstants.minTextHeight, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .disabled(restoreImageType == .latest)
            }.padding(.bottom)
                        
            Button("OK") {
                viewModel.showSettings = !viewModel.showSettings
            }.keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(minWidth: SizeConstants.totalWidth, maxWidth: SizeConstants.totalWidth)
        .onAppear() {
            diskSize = String(viewModel.diskSize)
            if let hardDiskDirectoryBookmarkData = UserDefaults.standard.hardDiskDirectoryBookmarkData,
               let hardDiskURL = Bookmark.startAccess(data: hardDiskDirectoryBookmarkData, forType: .hardDisk)
            {
                hardDiskLocation = .custom
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
            SettingsView(viewModel: ViewModel())
        }
    }
}

#endif
