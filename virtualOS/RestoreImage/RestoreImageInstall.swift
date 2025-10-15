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
    weak var delegate: ProgressDelegate?
    var restoreImageName: String?
    var diskImageSize: Int?

    fileprivate var observation: NSKeyValueObservation?
    fileprivate var installing = true
    fileprivate var installer:  VZMacOSInstaller?
    fileprivate let userInteractivQueue = DispatchQueue.global(qos: .userInteractive)

    deinit {
        observation?.invalidate()
    }

    func install() {
        let restoreImageURL: URL
        if let restoreImageName {
            restoreImageURL = URL(fileURLWithPath: URL.documentsPathURL.appendingPathComponent(restoreImageName).path())
        } else {
            restoreImageURL = URL.defaultRestoreImageURL
        }
        
        if !FileManager.default.fileExists(atPath: restoreImageURL.path) {
            Logger.shared.log(level: .default, "no restore image")
            delegate?.progress(0, progressString: "error: no restore image")
            return
        }
        
        loadParametersFromRestoreImage(restoreImageURL: restoreImageURL)
    }
    
    func cancel() {
        stopVM()
    }
    
    // MARK: - Private
    
    fileprivate func loadParametersFromRestoreImage(restoreImageURL: URL?) {
        guard let bundleURL = createBundleURL() else {
            self.delegate?.done(error: RestoreError(localizedDescription: "Failed to create VM bundle."))
            return
        }
        if let error = createBundle(at: bundleURL) {
            self.delegate?.done(error: error)
            return
        }
        
        guard let restoreImageURL else {
            self.delegate?.done(error: RestoreError(localizedDescription: "Restore image URL unavailable."))
            return // error
        }
        
        VZMacOSRestoreImage.load(from: restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
            case .success(let restoreImage):
                self.startInstall(restoreImage: restoreImage, bundleURL: bundleURL)
            case .failure(let error):
                self.delegate?.done(error: error)
            }
        }
    }
    
    fileprivate func startInstall(restoreImage: VZMacOSRestoreImage, bundleURL: URL)  {
        var versionString = ""
        guard let macPlatformConfiguration = MacPlatformConfiguration.createDefault(fromRestoreImage: restoreImage, versionString: &versionString, bundleURL: bundleURL) else {
            return
        }

        var vmParameters = VMParameters()
        let vmConfiguration = VMConfiguration()
        vmConfiguration.platform = macPlatformConfiguration
        
        if let diskImageSize = diskImageSize {
            vmParameters.diskSizeInGB = UInt64(diskImageSize)
            if createDiskImage(diskImageURL: bundleURL.diskImageURL, sizeInGB: UInt64(vmParameters.diskSizeInGB)) {
                return
            }
        }
        
        vmConfiguration.setDefault(parameters: &vmParameters)
        vmConfiguration.setup(parameters: vmParameters, macPlatformConfiguration: macPlatformConfiguration, bundleURL: bundleURL)
        
        vmParameters.version = restoreImage.operatingSystemVersionString
        vmParameters.writeToDisk(bundleURL: bundleURL)
        
        do {
            try vmConfiguration.validate()
            Logger.shared.log(level: .default, "vm configuration is valid, using \(vmParameters.cpuCount) cpus and \(vmParameters.memorySizeInGB) gb ram")
        } catch let error {
            Logger.shared.log(level: .default, "failed to validate vm configuration: \(error.localizedDescription)")
            return
        }

        let vm = VZVirtualMachine(configuration: vmConfiguration, queue: userInteractivQueue)
        
        var restoreImageURL = URL.defaultRestoreImageURL
        if let restoreImageName {
            // use custom restore image
            restoreImageURL = URL.documentsPathURL.appendingPathComponent(restoreImageName)
        }
        
        userInteractivQueue.async { [weak self] in
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: restoreImageURL)
            self?.installer = installer
            
            installer.install { result in
                self?.installing = false
                switch result {
                case .success():
                    self?.installFinisehd(installer: installer)
                case .failure(let error):
                    self?.delegate?.done(error: error)
                }
            }
            
            self?.observation = installer.progress.observe(\.fractionCompleted) { _, _ in }
            
            func updateInstallProgress() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    var progressString = "Installing \(Int(installer.progress.fractionCompleted * 100))%"
                    if installer.progress.fractionCompleted == 0 {
                        progressString += " (Please wait)"
                    }
                    progressString += "\n\(versionString)"
                    
                    if let installing = self?.installing, installing {
                        self?.delegate?.progress(installer.progress.fractionCompleted, progressString: progressString)
                        updateInstallProgress()
                    }
                }
            }

            updateInstallProgress()
        }
    }
    
    fileprivate func installFinisehd(installer: VZMacOSInstaller) {
        Logger.shared.log(level: .default, "Install finished")
        installing = false
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
    
    fileprivate func createBundleURL() -> URL? {
        guard let vmFilesDirectoryString = UserDefaults.standard.vmFilesDirectory,
           let vmFilesDirectoryBookmarkData = UserDefaults.standard.vmFilesDirectoryBookmarkData else
        {
            return nil // error
        }

        // try to find a filename that does not exist
        var url = URL(fileURLWithPath: vmFilesDirectoryString.appending(URL.bundleName))
        var exists = true
        var i = 1
        while exists {
            url = nextURL(url, i)
            if FileManager.default.fileExists(atPath: url.path) {
                i += 1
            } else {
                exists = false
            }
        }
        
        if Bookmark.startAccess(bookmarkData: vmFilesDirectoryBookmarkData, for: url.path) == nil {
            return nil // error
        }
        
        Logger.shared.log(level: .default, "using bundle url \(url.path(percentEncoded: false))")
        return url
    }
    
    fileprivate func nextURL(_ url: URL, _ i: Int) -> URL {
        var filename = url.lastPathComponent
        filename = filename.replacingOccurrences(of: ".bundle", with: "")
        
        let filenameComponents = filename.split(separator: "_")
        if filenameComponents.count > 0 {
            filename = String(filenameComponents[0])
        }
        filename += "_\(i).bundle"
        
        let path = url.deletingLastPathComponent().appendingPathComponent(filename, conformingTo: .bundle).path
        return URL(fileURLWithPath: path)
    }

    fileprivate func createBundle(at bundleURL: URL) -> RestoreError? {
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            return nil // already exists, no error
        }
        
        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            let errorMessage = "Failed to create VM bundle: \(error.localizedDescription)"
            Logger.shared.log(level: .default, "\(errorMessage)")
            return RestoreError(localizedDescription: errorMessage)
        }

        // Logger.shared.log(level: .default, "bundle created at \(bundleURL.path)")
        return nil // no error
    }
    
    fileprivate func createDiskImage(diskImageURL: URL, sizeInGB: UInt64) -> Bool {
        let diskImageFileDescriptor = open(diskImageURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskImageFileDescriptor == -1 {
            Logger.shared.log(level: .default, "error: cannot create disk image")
            return false // failure
        }

        let diskSize = sizeInGB.gigabytesToBytes()
        var result = ftruncate(diskImageFileDescriptor, Int64(diskSize))
        if result != 0 {
            Logger.shared.log(level: .default, "error: expanding disk image failed")
            return false // failure
        }

        result = close(diskImageFileDescriptor)
        if result != 0 {
            Logger.shared.log(level: .default, "error: failed to close the disk image")
            return false // failure
        }

        return false // failure
    }
}

#endif
