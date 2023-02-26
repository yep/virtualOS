//
//  MainViewModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 31.03.22.
//

#if arch(arm64)

import Foundation
import Virtualization
import OSLog

final class MainViewModel: NSObject, ObservableObject {
    enum State: String {
        case Downloading
        case Installing
        case Starting
        case Running
        case Stopping
        case Stopped
    }

    @Published var statusLabel = ""
    @Published var statusButtonLabel = ""
    @Published var statusButtonDisabled = false
    @Published var showStatusBar = true
    @Published var showLicenseInformationModal = false
    @Published var showConfirmationAlert = false
    @Published var showSettings = false
    @Published var isFullScreen = false
    @Published var useMainScreenSize = true
    @Published var licenseInformationTitleString = ""
    @Published var licenseInformationString = ""
    @Published var confirmationText = ""
    @Published var progress: Progress?
    @Published var confirmationHandler: CompletionHander = {_ in}
    @Published var virtualMac = VirtualMac()
    @Published var virtualMachine: VZVirtualMachine?
    @Published var customRestoreImageURL: URL?
    @Published var diskSize = UserDefaults.standard.diskSize {
        didSet {
            UserDefaults.standard.diskSize = diskSize
        }
    }
    @Published var state = State.Stopped {
        didSet {
            virtualOSApp.debugLog(self.state.rawValue)
            updateLabels(for: self.state)
        }
    }
    static var bundleExists: Bool {
        return FileManager.default.fileExists(atPath: URL.vmBundlePath)
    }
    static var diskImageExists: Bool {
        return FileManager.default.fileExists(atPath: URL.diskImageURL.path)
    }
    static var restoreImageExists: Bool {
        return FileManager.default.fileExists(atPath: URL.restoreImageURL.path)
    }

    var showConfigurationView: Bool {
        return (Self.diskImageExists || Self.restoreImageExists) && state == .Stopped
    }
    var showSettingsInfo: Bool {
        return !Self.diskImageExists && state == .Stopped
    }

    override init() {
        super.init()
        updateLabels(for: state)
        readParametersFromDisk()
        loadLicenseInformationFromBundle()
        moveFilesAfterUpdate()
    }

    func statusButtonPressed() {
        switch state {
            case .Stopped:
                start()
            case .Downloading:
                virtualMac.stopDownload()
                state = .Stopped
            case .Installing, .Starting, .Running, .Stopping:
                stop()
        }
    }

    func deleteRestoreImage() {
        confirmationText = "Restore Image"
        confirmationHandler = { _ in
            do {
                try FileManager.default.removeItem(atPath: URL.restoreImageURL.path)
            } catch {
                self.display(errorString: "Error: Could not delete restore image")
            }
        }
        showConfirmationAlert = !showConfirmationAlert
    }

    func deleteVirtualMachine() {
        confirmationText = "Virtual Machine"
        confirmationHandler = { _ in
            if Self.bundleExists {
                self.stop()
                do {
                    try FileManager.default.removeItem(at: URL.vmBundleURL)
                    self.updateLabels(for: self.state)
                } catch {
                    self.display(errorString: "Error: Could not delete virtual machine")
                }
            }
        }
        showConfirmationAlert = !showConfirmationAlert
    }

    func loadLicenseInformationFromBundle() {
        if let filepath = Bundle.main.path(forResource: "LICENSE", ofType: "") {
            do {
                let contents = try String(contentsOfFile: filepath)
                licenseInformationString = contents
            } catch {
                licenseInformationString = "Failed to load license information"
            }
        } else {
            licenseInformationString = "License information not found"
        }

        licenseInformationTitleString = "virtualOS"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
            licenseInformationTitleString += " \(version) (Build \(build))"
        }
    }

    // MARK: - Private

    fileprivate func readParametersFromDisk() {
        if Self.diskImageExists {
            // read previous vm settings
            if let errorString = virtualMac.readFromDisk(delegate: self) {
                display(errorString: errorString)
            }
        } else if Self.restoreImageExists {
            virtualMac.loadParametersFromRestoreImage(customRestoreImageURL: nil) { (errorString: String?) in
                if let errorString = errorString {
                    self.display(errorString: errorString)
                }
            }
        }
    }

    fileprivate func start() {
        virtualOSApp.debugLog("Using storage directory \(URL.vmBundlePath)")
        if FileManager.default.fileExists(atPath: URL.diskImageURL.path) {
            startFromDiskImage()
        } else if FileManager.default.fileExists(atPath: URL.restoreImageURL.path) || customRestoreImageURL != nil {
            install(virtualMac: virtualMac)
        } else {
            downloadAndInstall()
        }
    }

    fileprivate func downloadAndInstall() {
        state = .Downloading
        statusButtonLabel = "Stop"

        virtualMac.downloadRestoreImage { (progress: Progress) in
            virtualOSApp.debugLog("Download progress: \(progress.fractionCompleted * 100)%")
            self.progress = progress
            self.updateLabels(for: self.state)
        } completionHandler: { (errorString: String?) in
            if let errorString = errorString {
                self.display(errorString: "Download of restore image failed: \(errorString)")
            } else {
                virtualOSApp.debugLog("Download of restore image completed")
                self.install(virtualMac: self.virtualMac)
            }
        }
    }

    fileprivate func install(virtualMac: VirtualMac) {
        state = .Installing
        virtualMac.install(delegate: self, customRestoreImageURL: customRestoreImageURL) { (progress: Progress) in
            virtualOSApp.debugLog("Install progress: \(progress.completedUnitCount)%")
            self.progress = progress
            self.updateLabels(for: self.state)
        } completionHandler: { (errorString: String?, virtualMachine: VZVirtualMachine?) in
            DispatchQueue.main.async {
                self.progress = nil
            }
            if let errorString = errorString {
                self.display(errorString: errorString)
            } else if let virtualMachine = virtualMachine {
                self.start(virtualMachine: virtualMachine)
            } else {
                self.display(errorString: "Error: Install finished but no virtual machine created")
            }
        }
    }

    fileprivate func startFromDiskImage() {
        guard let virtualMachine = virtualMac.createVirtualMachine(delegate: self) else {
            display(errorString: "Error: Failed to read virtual machine from disk")
            return
        }

        start(virtualMachine: virtualMachine)
    }

    fileprivate func start(virtualMachine: VZVirtualMachine) {
        self.state = .Starting
        self.virtualMachine = virtualMachine

        if let errorString = virtualMac.writeParametersToDisk() {
            display(errorString: errorString)
        }

        virtualMachine.start { (result: Result<Void, Error>) in
            switch result {
                case .success:
                    self.state = .Running
                case .failure(let error):
                    self.display(errorString: "Error while starting: \(error)")
            }
        }
    }

    fileprivate func stop() {
        guard let virtualMachine = virtualMachine else {
            return // already stopped
        }
        state = .Stopping

        virtualMachine.stop(completionHandler: { (error: Error?) in
            self.state = .Stopped
            if let error = error {
                self.display(errorString: error.localizedDescription)
            }
            self.virtualMachine = nil
        })
    }

    fileprivate func display(errorString: String) {
        virtualOSApp.debugLog(errorString)
        
        let displayErrorString = {
            self.state = .Stopped
            self.statusLabel = errorString
        }
        
        if Thread.isMainThread {
            displayErrorString()
        } else {
            DispatchQueue.main.async {
                displayErrorString()
            }
        }
    }

    fileprivate func updateLabels(for: State) {
        switch state {
            case .Stopped:
                statusLabel = state.rawValue
                statusButtonLabel = "Start"
            case .Downloading:
                if let progress = progress {
                    updateDownloadProgress(progress)
                }
                statusButtonLabel = "Stop"
            case .Installing:
                if let progress = progress {
                    statusLabel = "Installing macOS \(virtualMac.versionString): "
                    if progress.completedUnitCount == 0 {
                        statusLabel = statusLabel + "Waiting for begin, this may take some time …"
                    } else {
                        statusLabel = statusLabel + "\(progress.completedUnitCount)%"
                    }
                }
                statusButtonLabel = "Stop"
            case .Starting, .Running, .Stopping:
                statusLabel = state.rawValue
                statusButtonLabel = "Stop"
        }

        if state == .Installing {
            statusButtonDisabled = true // installing can not be canceled
        } else {
            statusButtonDisabled = false
        }
    }
    
    fileprivate func updateDownloadProgress(_ progress: Progress) {
        var statusText = String(format: "Downloading restore image: %2.2f%%", progress.fractionCompleted * 100)
        
        if let byteCompletedCount = progress.userInfo[ProgressUserInfoKey("NSProgressByteCompletedCountKey")] as? Int,
           let byteTotalCount = progress.userInfo[ProgressUserInfoKey("NSProgressByteTotalCountKey")] as? Int
        {
            let mbCompleted = byteCompletedCount / (1024 * 1024)
            let mbTotal     = byteTotalCount / (1024 * 1024)
            statusText += " (\(mbCompleted) of \(mbTotal) MB)"
        }
        
        statusLabel = statusText
    }
    
    fileprivate func moveFilesAfterUpdate() {
        let oldRestoreImageLocation = URL(fileURLWithPath: NSHomeDirectory() + "/RestoreImage.ipsw")
        let newRestoreImageLocation = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/RestoreImage.ipsw")
        try? FileManager.default.moveItem(at: oldRestoreImageLocation, to: newRestoreImageLocation)

        let oldVirtualMachineLocation = URL(fileURLWithPath: NSHomeDirectory() + "/virtualOS.bundle")
        let newVirtualMachineLocation = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/virtualOS.bundle")
        try? FileManager.default.moveItem(at: oldVirtualMachineLocation, to: newVirtualMachineLocation)
    }
}

extension MainViewModel: VZVirtualMachineDelegate {
    func guestDidStop(_ vm: VZVirtualMachine) {
        state = .Stopped
    }

    func virtualMachine(_ vm: VZVirtualMachine, didStopWithError error: Error) {
        display(errorString: error.localizedDescription)
    }
}

#endif
