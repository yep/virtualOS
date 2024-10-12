//
//  RestoreImageInstall.swift
//  virtualOS
//
//  Created by Jahn Bertsch
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
    fileprivate let queue = DispatchQueue.global(qos: .userInteractive)
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")

    deinit {
        observation?.invalidate()
    }

    func install() {
        let restoreImageURL: URL
        if let restoreImageName {
            restoreImageURL = URL.baseURL.appendingPathComponent(restoreImageName)
        } else {
            restoreImageURL = URL.restoreImageURL
        }
        
        if !FileManager.default.fileExists(atPath: restoreImageURL.path) {
            logger.log(level: .default, "no restore image")
            delegate?.progress(0, progressString: "Error: No restore image")
            return
        }
        
        loadParametersFromRestoreImage(restoreImageURL: restoreImageURL)
    }
    
    func cancel() {
        queue.async { [weak self] in
            self?.installer?.virtualMachine.stop(completionHandler: { error in
                if let error {
                    self?.logger.log(level: .default, "vm stopped with error: \(error.localizedDescription)")
                } else {
                    self?.logger.log(level: .default, "vm stopped")
                }
            })
        }
    }
    
    // MARK: - Private
    
    fileprivate func loadParametersFromRestoreImage(restoreImageURL: URL?) {
        let bundleURl = createBundleURL()
        if !createBundle(at: bundleURl) {
            return // error
        }
        
        guard let restoreImageURL else {
            return
        }
        
        VZMacOSRestoreImage.load(from: restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
            case .success(let restoreImage):
                self.restoreImageDidLoad(restoreImage: restoreImage, bundleURL: bundleURl)
            case .failure(let failure):
                self.logger.log(level: .default, "could not load restore image: \(failure)")
            }
        }
    }
    
    fileprivate func restoreImageDidLoad(restoreImage: VZMacOSRestoreImage, bundleURL: URL)  {
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
            logger.log(level: .default, "vm configuration is valid")
        } catch let error {
            logger.log(level: .default, "failed to validate vm configuration: \(error.localizedDescription)")
            return
        }

        startInstall(vmConfiguration: vmConfiguration, versionString: versionString)
    }
    
    fileprivate func startInstall(vmConfiguration: VMConfiguration, versionString: String) {
        let vm = VZVirtualMachine(configuration: vmConfiguration, queue: queue)
        
        var restoreImageURL = URL.restoreImageURL
        if let restoreImageName {
            // use custom restore image
            restoreImageURL = URL.baseURL.appendingPathComponent(restoreImageName)
        }
        
        queue.async { [weak self] in
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: restoreImageURL)
            self?.installer = installer
            
            installer.install { result in
                self?.installing = false
                switch result {
                case .success():
                    self?.installFinisehd(installer: installer)
                case .failure(let error):
                    self?.logger.log(level: .default, "install error: \(error.localizedDescription)")
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.done()
                    }
                }
            }
            
            self?.observation = installer.progress.observe(\.fractionCompleted) { _, _ in }
            
            func printProgress() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    var progressString = "Installing \(Int(installer.progress.fractionCompleted * 100))%"
                    if installer.progress.fractionCompleted == 0 {
                        progressString += " (Please wait)"
                    }
                    progressString += "\n\(versionString)"
                    // logger.log(level: .default, progressString)
                    
                    if let installing = self?.installing, installing {
                        self?.delegate?.progress(installer.progress.fractionCompleted, progressString: progressString)
                        printProgress()
                    }
                }
            }
            printProgress()
        }
    }
    
    fileprivate func installFinisehd(installer: VZMacOSInstaller) {
        logger.log(level: .default, "Install finished")
        
        installing = false

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.progress(installer.progress.fractionCompleted, progressString: "Install finished")
        }
        delegate?.done()
        
        if installer.virtualMachine.canStop {
            queue.async {
                installer.virtualMachine.stop(completionHandler: { error in
                    if let error {
                        self.logger.log(level: .default, "Error stopping VM: \(error)")
                    }
                })                
            }
        }
    }
    
    fileprivate func createBundleURL() -> URL {
        var url = URL.vmBundleURL
        
        // try to find a filename that does not exist
        var exists = true
        var i = 1
        while exists {
            var filename = url.lastPathComponent
            filename = filename.replacingOccurrences(of: ".bundle", with: "")
            let filenameComponents = filename.split(separator: "_")
            if filenameComponents.count > 0 {
                filename = String(filenameComponents[0])
            }
            filename += "_\(i).bundle"

            url = URL(fileURLWithPath: URL.baseURL.appendingPathComponent(filename, conformingTo: .bundle).path())

            if FileManager.default.fileExists(atPath: url.path()) {
                i += 1
            } else {
                exists = false
            }
        }
        logger.log(level: .default, "using bundle url \(url.lastPathComponent)")
        return url
    }
    
    fileprivate func createBundle(at bundleURl: URL) -> Bool {
        if FileManager.default.fileExists(atPath: bundleURl.path()) {
            return true // already exists, no error
        }

        let bundleFileDescriptor = mkdir(bundleURl.path(), S_IRWXU | S_IRWXG | S_IRWXO)
        if bundleFileDescriptor == -1 {
            if errno == EEXIST {
                logger.log(level: .default, "failed to create vm bundle: the base directory already exists")
            }
            logger.log(level: .default, "failed to create vm bundle at \(bundleURl.path()) (error number \(errno))")
            return false // error
        }

        let result = close(bundleFileDescriptor)
        if result != 0 {
            logger.log(level: .default, "failed to close vm bundle (\(result))")
            return false // error
        }

        return true // no error
    }
    
    fileprivate func createDiskImage(diskImageURL: URL, sizeInGB: UInt64) -> Bool {
        let diskImageFileDescriptor = open(diskImageURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskImageFileDescriptor == -1 {
            logger.log(level: .default, "Error: Cannot create disk image")
            return false // failure
        }

        let diskSize = sizeInGB.gigabytesToBytes()
        var result = ftruncate(diskImageFileDescriptor, Int64(diskSize))
        if result != 0 {
            logger.log(level: .default, "Error: Expanding disk image failed")
            return false // failure
        }

        result = close(diskImageFileDescriptor)
        if result != 0 {
            logger.log(level: .default, "Error: Failed to close the disk image")
            return false // failure
        }

        return false // failure
    }

}

#endif
