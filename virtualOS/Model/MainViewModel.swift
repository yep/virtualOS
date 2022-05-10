//
//  MainViewModel.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 31.03.22.
//

#if arch(arm64)

import Foundation
import Virtualization

final class MainViewModel: NSObject, ObservableObject {
    enum State: String {
        case Downloading
        case Installing
        case Starting
        case Running
        case Stopping
        case Stopped
    }

    @Published var virtualMac = VirtualMac()
    @Published var virtualMachine: VZVirtualMachine?
    @Published var statusLabel = ""
    @Published var buttonLabel = ""
    @Published var buttonDisabled = false
    @Published var installProgress: Progress?
    @Published var showLicenseInformationModal = false
    @Published var showConfirmationAlert = false
    @Published var licenseInformationTitleString = ""
    @Published var licenseInformationString = ""
    @Published var confirmationText = ""
    @Published var confirmationHandler: CompletionHander = {_ in}
    @Published var state = State.Stopped {
        didSet {
            debugLog(self.state.rawValue)
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
    var settingsShown: Bool {
        return (Self.diskImageExists || Self.restoreImageExists) && state == .Stopped
    }

    override init() {
        super.init()
        updateLabels(for: state)
        readParametersFromDisk()
        loadLicenseInformationFromBundle()
    }

    func buttonPressed() {
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
            virtualMac.loadParametersFromRestoreImage { (errorString: String?) in
                if let errorString = errorString {
                    self.display(errorString: errorString)
                }
            }
        }
    }

    fileprivate func start() {
        debugLog("Using storage directory \(URL.vmBundlePath)")
        if FileManager.default.fileExists(atPath: URL.diskImageURL.path) {
            startFromDiskImage()
        } else if FileManager.default.fileExists(atPath: URL.restoreImageURL.path) {
            install(virtualMac: virtualMac)
        } else {
            downloadAndInstall()
        }
    }

    fileprivate func downloadAndInstall() {
        state = .Downloading
        buttonLabel = "Stop"

        virtualMac.downloadRestoreImage { (progress: Progress) in
            debugLog("Download progress: \(progress.fractionCompleted * 100)%")
            self.installProgress = progress
            self.updateLabels(for: self.state)
        } completionHandler: { (errorString: String?) in
            if let errorString = errorString {
                self.display(errorString: "Download of restore image failed: \(errorString)")
            } else {
                debugLog("Download of restore image completed")
                self.install(virtualMac: self.virtualMac)
            }
        }
    }

    fileprivate func install(virtualMac: VirtualMac) {
        state = .Installing
        virtualMac.install(delegate: self) { (progress: Progress) in
            debugLog("Install progress: \(progress.completedUnitCount)%")
            self.installProgress = progress
            self.updateLabels(for: self.state)
        } completionHandler: { (errorMessage: String?, virtualMachine: VZVirtualMachine?) in
            self.installProgress = nil
            if let errorMessage = errorMessage {
                self.display(errorString: errorMessage)
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
        debugLog(errorString)
        self.state = .Stopped
        self.statusLabel = errorString
    }

    fileprivate func updateLabels(for: State) {
        switch state {
            case .Stopped:
                statusLabel = state.rawValue
                buttonLabel = "Start"
            case .Downloading:
                if let installProgress = installProgress {
                    statusLabel = String(format: "Downloading restore image: %2.2f%%", installProgress.fractionCompleted * 100)
                }
                buttonLabel = "Stop"
            case .Installing:
                if let installProgress = installProgress {
                    if installProgress.completedUnitCount == 0 {
                        statusLabel = "Installing: Waiting for begin …"
                    } else {
                        statusLabel = "Installing: \(installProgress.completedUnitCount)%"
                    }
                }
                buttonLabel = "Stop"
            case .Starting, .Running, .Stopping:
                statusLabel = state.rawValue
                buttonLabel = "Stop"
        }

        if state == .Installing {
            buttonDisabled = true // installing can not be canceled
        } else {
            buttonDisabled = false
        }
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
