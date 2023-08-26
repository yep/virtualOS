//
//  ConfigurationView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 03.04.22.
//

#if arch(arm64)

import SwiftUI

struct ConfigurationView: View {
    enum ScreenSize: Int, Codable {
        case custom = 1
        case mainScreen = 2
    }
    public enum SharedFolderType: Int, Codable {
        case none = 1
        case custom = 2
    }

    @ObservedObject var viewModel: ViewModel
    @State fileprivate var cpuCountSliderValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.cpuCount = Int(cpuCountSliderValue)
        }
    }
    @State fileprivate var memorySliderValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.memorySizeInGB = UInt64(memorySliderValue)
        }
    }
    @State fileprivate var screenWidthValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.screenWidth = Int(screenWidthValue)
        }
    }
    @State fileprivate var screenHeightValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.screenHeight = Int(screenHeightValue)
        }
    }
    @State fileprivate var screenSize: ScreenSize = .mainScreen
    @State var sharedFolderType: SharedFolderType = .none

    fileprivate var sharedFolderInfo: String {
        if #available(macOS 13.0, *) {
            if sharedFolderType == .custom,
               let hardDiskDirectoryBookmarkData = Bookmark.startAccess(data: viewModel.virtualMac.parameters.sharedFolder, forType: .sharedFolder)
            {
                if viewModel.sharedFolderExists {
                    return "Using \(hardDiskDirectoryBookmarkData.path)"
                } else {
                    return "Shared folder not found."
                }
            } else {
                return "No shared folder selected."
            }
        } else {
            return "Shared folders require macOS 13 or newer."
        }
    }
    fileprivate let textWidth = CGFloat(150)

    var body: some View {
        VStack {
            Spacer()
            VStack {
                let parameters = viewModel.virtualMac.parameters
                Text("Virtual Machine Configuration").font(.headline)

                Slider(value: Binding(get: {
                    cpuCountSliderValue
                }, set: { (newValue) in
                    cpuCountSliderValue = newValue
                }), in: Float(parameters.cpuCountMin) ... Float(parameters.cpuCountMax), step: 1) {
                    Text("CPU Count: \(viewModel.virtualMac.parameters.cpuCount)")
                        .frame(minWidth: textWidth, alignment: .leading)
                }

                Slider(value: Binding(get: {
                    memorySliderValue
                }, set: { (newValue) in
                    memorySliderValue = newValue
                }), in: Float(parameters.memorySizeInGBMin) ... Float(parameters.memorySizeInGBMax), step: 1) {
                    Text("RAM: \(viewModel.virtualMac.parameters.memorySizeInGB) GB")
                        .frame(minWidth: textWidth, alignment: .leading)
                }
                 
                HStack() {
                    Text("Screen Size").frame(minWidth: textWidth, alignment: .leading)
                    Picker("", selection: $screenSize) {
                        Text("Main Screen").tag(ScreenSize.mainScreen)
                        Text("Custom").tag(ScreenSize.custom)
                    }.pickerStyle(.inline)
                        .onChange(of: screenSize) { newValue in
                            viewModel.virtualMac.parameters.useMainScreenSize = newValue == .mainScreen
                            if let mainScreen = NSScreen.main {
                                screenWidthValue  = Float(mainScreen.frame.width)
                                screenHeightValue = Float(mainScreen.frame.height)
                            }
                        }
                    Spacer()
                }

                Slider(value: Binding(get: {
                    screenWidthValue
                }, set: { (newValue) in
                    screenWidthValue = newValue
                }), in: 800 ... Float(NSScreen.main?.frame.width ?? CGFloat(parameters.screenWidth)), step: 100) {
                    Text("Screen Width: \(viewModel.virtualMac.parameters.screenWidth) px")
                        .frame(minWidth: textWidth, alignment: .leading)
                }.disabled(screenSize == .mainScreen)

                Slider(value: Binding(get: {
                    screenHeightValue
                }, set: { (newValue) in
                    screenHeightValue = newValue
                }), in: 600 ... Float(NSScreen.main?.frame.height ?? CGFloat(parameters.screenHeight)), step: 50) {
                    Text("Screen Height: \(viewModel.virtualMac.parameters.screenHeight) px")
                        .frame(minWidth: textWidth, alignment: .leading)
                }.disabled(screenSize == .mainScreen)
            
                HStack() {
                    Text("Shared Folder").frame(minWidth: textWidth, alignment: .leading)
                    VStack(alignment: .leading, content: {
                        Picker("", selection: $sharedFolderType) {
                            Text("No shared folder").tag(SharedFolderType.none)
                            Text("Custom").tag(SharedFolderType.custom)
                        }.pickerStyle(.inline)
                        Button("Select Shared Folder") {
                            selectSharedFolder()
                        }   .disabled(sharedFolderType == .none)
                            .padding(.top, 7)
                        Text(sharedFolderInfo)
                            .font(.caption)
                            .frame(maxWidth: 270, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .disabled(sharedFolderType == .none)
                    })
                }
            }
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                .stroke(.tertiary, lineWidth: 1)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            onAppear()
        }
    }
    
    // MARK: - Private
    
    fileprivate func selectSharedFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select"
        if openPanel.runModal() == .OK,
           let selectedURL = openPanel.url
        {
            viewModel.set(sharedFolderUrl: selectedURL)
        }
    }
    
    fileprivate func onAppear() {
        let parameters      = viewModel.virtualMac.parameters
        cpuCountSliderValue = Float(parameters.cpuCount)
        memorySliderValue   = Float(parameters.memorySizeInGB)
        screenWidthValue    = Float(parameters.screenWidth)
        screenHeightValue   = Float(parameters.screenHeight)
        if parameters.useMainScreenSize {
            screenSize = .mainScreen
        } else {
            screenSize = .custom
        }
        if let hardDiskDirectoryBookmarkData = UserDefaults.standard.hardDiskDirectoryBookmarkData {
            _ = Bookmark.startAccess(data: hardDiskDirectoryBookmarkData, forType: .hardDisk)
        }
        if Bookmark.startAccess(data: parameters.sharedFolder, forType: .sharedFolder) != nil {
            sharedFolderType = .custom
        }
    }
}

struct ConfigurationViewProvider_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ConfigurationView(viewModel: ViewModel())
        }
    }
}

#endif
