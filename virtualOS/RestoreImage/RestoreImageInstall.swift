//
//  RestoreImageInstall.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation
import Virtualization
import OSLog

#if arch(arm64)

final class RestoreImageInstall {
    fileprivate struct InstallState {
        fileprivate var installing = true
        fileprivate var vmParameters: VMParameters?
        fileprivate var bundleURL: URL?
    }
    
    weak var delegate: ProgressDelegate?
    var restoreImageName: String?
    var diskImageSize: Int?

    fileprivate var observation: NSKeyValueObservation?
    fileprivate var installer:  VZMacOSInstaller?
    fileprivate let userInteractivQueue = DispatchQueue.global(qos: .userInteractive)
    fileprivate var installState = InstallState()

    deinit {
        observation?.invalidate()
    }

    func install() {
        guard let restoreImageName else {
            self.delegate?.done(error: RestoreError(localizedDescription: "Restore image name unavailable."))
            return // error
        }
        let restoreImagesDirectoryURL = URL.startAccessingRestoreImagesDirectory()
        let restoreImageURL = restoreImagesDirectoryURL.appending(path: restoreImageName)
        guard FileManager.default.fileExists(atPath: URL.restoreImageURL.path) else {
            delegate?.done(error: RestoreError(localizedDescription: "Restore image does not exist at \(restoreImageURL.path)"))
            return
        }

        let vmFilesDirectoryURL = URL.startAccessingVMFilesDirectory()
        let bundleURL = URL.createFilename(baseURL: vmFilesDirectoryURL, name: "virtualOS", suffix: "bundle")
        if let error = createBundle(at: bundleURL) {
            self.delegate?.done(error: error)
            return
        }
        installState.bundleURL = bundleURL
        Logger.shared.log(level: .default, "using bundle url \(bundleURL.path)")

        VZMacOSRestoreImage.load(from: restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
            case .success(let restoreImage):
                self.restoreImageLoaded(restoreImage: restoreImage, bundleURL: bundleURL)
            case .failure(let error):
                self.delegate?.done(error: error)
            }
        }
    }
    
    func cancel() {
        stopVM()
    }
    
    // MARK: - Private
    
    fileprivate func restoreImageLoaded(restoreImage: VZMacOSRestoreImage, bundleURL: URL)  {
        var versionString = ""
        let macPlatformConfigurationResult = MacPlatformConfiguration.createDefault(fromRestoreImage: restoreImage, versionString: &versionString, bundleURL: bundleURL)
        if case .failure(let error) = macPlatformConfigurationResult {
            delegate?.done(error: error)
            return
        }
        
        var vmParameters = VMParameters()
        let vmConfiguration = VMConfiguration()
        if case .success(let macPlatformConfiguration) = macPlatformConfigurationResult,
           let macPlatformConfiguration
        {
            vmConfiguration.platform = macPlatformConfiguration
            
            if let diskImageSize = diskImageSize {
                vmParameters.diskSizeInGB = UInt64(diskImageSize)
                if #available(macOS 27.0, *) {
                    do {
                        _ = try SnapshotModel.createBaseImage(
                            bundleURL: bundleURL,
                            sizeInBytes: vmParameters.diskSizeInGB.gigabytesToBytes()
                        )
                    } catch {
                        delegate?.done(error: error)
                        return
                    }
                } else {
                    let restoreResult = createDiskImage(diskImageURL: bundleURL.diskImageURL, sizeInGB: UInt64(vmParameters.diskSizeInGB))
                    if case .failure(let restoreError) = restoreResult {
                        delegate?.done(error: restoreError)
                        return
                    }
                }
            }
            
            vmConfiguration.setDefault(parameters: &vmParameters)
            do {
                try vmConfiguration.setup(parameters: vmParameters, macPlatformConfiguration: macPlatformConfiguration, bundleURL: bundleURL)
            } catch {
                delegate?.done(error: error)
                return
            }
        } else {
            delegate?.done(error: RestoreError(localizedDescription: "Could not create mac platform configuration."))
            return
        }
        
        vmParameters.version = restoreImage.operatingSystemVersionString
        vmParameters.writeToDisk(bundleURL: bundleURL)
        installState.vmParameters = vmParameters // keep reference to update installFinished parameter later
        
        do {
            try vmConfiguration.validate()
            Logger.shared.log(level: .default, "vm configuration is valid, using \(vmParameters.cpuCount) cpus and \(vmParameters.memorySizeInGB) gb ram")
        } catch let error {
            Logger.shared.log(level: .default, "failed to validate vm configuration: \(error.localizedDescription)")
            return
        }

        let vm = VZVirtualMachine(configuration: vmConfiguration, queue: userInteractivQueue)
        
        userInteractivQueue.async { [weak self] in
            guard let self else {
                Logger.shared.log(level: .default, "Error: Could not install VM, weak self is nil")
                return
            }
            startMacOSInstaller(vm: vm, restoreImageURL: restoreImage.url, versionString: versionString)
        }
    }
    
    fileprivate func startMacOSInstaller(vm: VZVirtualMachine, restoreImageURL: URL, versionString: String) {
        let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: restoreImageURL)
        self.installer = installer
        
        installer.install { result in
            self.installState.installing = false
            switch result {
            case .success():
                self.installFinished(installer: installer)
            case .failure(let error):
                self.delegate?.done(error: error)
            }
        }
        
        self.observation = installer.progress.observe(\.fractionCompleted) { _, _ in }
        
        func updateInstallProgress() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                var progressString = "Installing \(Int(installer.progress.fractionCompleted * 100))%"
                if installer.progress.fractionCompleted == 0 {
                    progressString += " (Please wait)"
                }
                progressString += "\n\(versionString)"
                
                if let installing = self?.installState.installing, installing {
                    self?.delegate?.progress(installer.progress.fractionCompleted, progressString: progressString)
                    updateInstallProgress()
                }
            }
        }

        updateInstallProgress()
    }
    
    fileprivate func installFinished(installer: VZMacOSInstaller) {
        Logger.shared.log(level: .default, "Install finished")
        installState.installing = false
        installState.vmParameters?.installFinished = true
        if let bundleURL = installState.bundleURL {
            installState.vmParameters?.writeToDisk(bundleURL: bundleURL)            
        }
        delegate?.progress(installer.progress.fractionCompleted, progressString: "Install finished successfully.")
        delegate?.done(error: nil)
        stopVM()
    }
    
    fileprivate func stopVM() {
        if let installer = installer {
            userInteractivQueue.async {
                if installer.virtualMachine.canStop {
                    installer.virtualMachine.stop(completionHandler: { error in
                        if let error {
                            Logger.shared.log(level: .default, "Error stopping VM: \(error.localizedDescription)")
                        } else {
                            Logger.shared.log(level: .default, "VM stopped")
                        }
                    })
                }
            }
        }
    }
    
    fileprivate func createBundle(at bundleURL: URL) -> RestoreError? {
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return nil // already exists, no error
        }
        
        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            return RestoreError(localizedDescription: "Failed to create VM bundle directory: \(error.localizedDescription)")
        }

        // Logger.shared.log(level: .default, "bundle created at \(bundleURL.path)")
        return nil // no error
    }
    
    fileprivate func createDiskImage(diskImageURL: URL, sizeInGB: UInt64) -> RestoreResult {
        let diskImageFileDescriptor = open(diskImageURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskImageFileDescriptor == -1 {
            return RestoreResult(errorMessage: "Error: can not create disk image")
        }

        let diskSize = sizeInGB.gigabytesToBytes()
        var result = ftruncate(diskImageFileDescriptor, Int64(diskSize))
        if result != 0 {
            return RestoreResult(errorMessage: "Error: expanding disk image failed")
        }

        result = close(diskImageFileDescriptor)
        if result != 0 {
            return RestoreResult(errorMessage: "Error: failed to close the disk image")
        }

        return RestoreResult() // success
    }
}

#endif
