//
//  VirtualMac.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

#if arch(arm64)

import Virtualization

final class VirtualMac: ObservableObject {
    struct Parameters: Codable {
        var cpuCount = 1
        var cpuCountMin = 1
        var cpuCountMax = 2
        var diskSizeInGB: UInt64 = 64
        var memorySizeInGB: UInt64 = 1
        var memorySizeInGBMin: UInt64 = 1
        var memorySizeInGBMax: UInt64 = 2
        var screenWidth = 1500
        var screenHeight = 900
        var pixelsPerInch = 250
        var microphoneEnabled = false
    }

    typealias InstallCompletionHander = (String?, VZVirtualMachine?) -> Void    

    var parameters = Parameters()
    var virtualMachineConfiguration: VirtualMacConfiguration?
    fileprivate var progressObserver: NSKeyValueObservation?
    fileprivate var downloadTask: URLSessionDownloadTask?

    func readFromDisk(delegate: VZVirtualMachineDelegate) -> String? {
        if let errorString = readParametersFromDisk() {
            return errorString
        }

        let virtualMacConfiguration = VirtualMacConfiguration()
        virtualMacConfiguration.readFromDisk(using: &parameters)

        do {
            try virtualMacConfiguration.validate()
            self.virtualMachineConfiguration = virtualMacConfiguration
        } catch {
            return "Error: Failed to validate virtual machine configuration from disk"
        }

        return nil
    }

    func downloadRestoreImage(progressHandler: @escaping ProgressHandler, completionHandler: @escaping CompletionHander) {
        if let errorString = createBundle() {
            completionHandler(errorString)
            return
        }

        if FileManager.default.fileExists(atPath: URL.restoreImageURL.path) {
            completionHandler(nil) // done: already downloaded
        } else {
            fetchLatestSupportedRestoreImage(progressHandler: progressHandler, completionHandler: { (errorString: String?) in
                if let errorString = errorString {
                    completionHandler(errorString)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }

    func install(delegate: VZVirtualMachineDelegate, progressHandler: @escaping ProgressHandler, completionHandler: @escaping InstallCompletionHander) {
        loadParametersFromRestoreImage { (errorString: String?) in
            if let errorString = errorString {
                completionHandler(errorString, nil)
            } else {
                self.loadRestoreImage(delegate: delegate, progressHandler: progressHandler, completionHandler: completionHandler)
            }
        }
    }

    func loadParametersFromRestoreImage(completionHandler: @escaping CompletionHander) {
        if let errorString = createBundle() {
            completionHandler(errorString)
            return
        }

        VZMacOSRestoreImage.load(from: URL.restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
                case .success(let restoreImage):
                    self.loaded(restoreImage: restoreImage, completionHandler: completionHandler)
                case .failure(_):
                    completionHandler("Error: failure reading restore image")
            }
        }
    }

    func loadRestoreImage(delegate: VZVirtualMachineDelegate, progressHandler: @escaping ProgressHandler, completionHandler: @escaping InstallCompletionHander)  {
        VZMacOSRestoreImage.load(from: URL.restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
                case .success(let restoreImage):
                    if let errorString = self.restore(from: restoreImage) {
                        completionHandler(errorString, nil)
                    } else if let virtualMachineConfiguration = self.virtualMachineConfiguration {
                        self.startInstall(ipswURL: URL.restoreImageURL, virtualMacConfiguration: virtualMachineConfiguration, delegate: delegate, progressHandler: progressHandler, completionHandler: completionHandler)
                    } else {
                        completionHandler("Error: No virtual machine configuration found", nil)
                    }
                case .failure(let failure):
                    completionHandler("Loading restore image failed: \(failure)", nil)
                    return
            }
        }
    }

    func createVirtualMachine(delegate: VZVirtualMachineDelegate) -> VZVirtualMachine? {
        guard let virtualMacConfiguration = virtualMachineConfiguration else {
            return nil
        }
        virtualMacConfiguration.configure(with: &parameters)

        do {
            try virtualMacConfiguration.validate()
            self.virtualMachineConfiguration = virtualMacConfiguration
        } catch (let error) {
            debugLog("Error: \(error.localizedDescription)")
            return nil
        }

        if let errorString = writeParametersToDisk() {
            debugLog(errorString)
            return nil
        }
        
        let virtualMachine = VZVirtualMachine(configuration: virtualMacConfiguration, queue: .main)
        virtualMachine.delegate = delegate

        debugLog("Using \(virtualMacConfiguration.cpuCount) cores, \(virtualMacConfiguration.memorySize.bytesToGigabytes()) GB RAM and screen size \(parameters.screenWidth)x\(parameters.screenHeight) px at \(parameters.pixelsPerInch) ppi")
        return virtualMachine
    }

    func stop(virtualMachine: VZVirtualMachine, completionHandler: @escaping InstallCompletionHander) {
        virtualMachine.stop(completionHandler: { (error: Error?) in
            if let error = error {
                debugLog("Error while stopping: \(error)")
                completionHandler(error.localizedDescription, nil)
            } else {
                debugLog("Stopped")
                completionHandler(nil, virtualMachine) // nil: no error
            }
        })
    }

    func stopDownload() {
        downloadTask?.cancel()
    }

    func writeParametersToDisk() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(parameters)
            if let json = String(data: jsonData, encoding: .utf8) {
                try json.write(to: URL.parametersURL, atomically: true, encoding: String.Encoding.utf8)
            }
        } catch {
            return "Error: Failed to write current CPU and RAM configuration to disk"
        }
        return nil
    }

    // MARK: - Private

    fileprivate func readParametersFromDisk() -> String? {
        let decoder = JSONDecoder()
        do {
            let json = try Data.init(contentsOf: URL.parametersURL)
            parameters = try decoder.decode(Parameters.self, from: json)
        } catch {
            return "Error: Failed to read parameters, please delete virtual machine in 'File' menu"
        }
        return nil
    }

    fileprivate func fetchLatestSupportedRestoreImage(progressHandler: @escaping ProgressHandler, completionHandler: @escaping CompletionHander) {
        debugLog("Attempting to download latest available restore image")
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    completionHandler(error.localizedDescription)
                case let .success(restoreImage):
                    downloaded(restoreImage: restoreImage, progressHandler: progressHandler, completionHandler: completionHandler)
            }
        }
    }

    fileprivate func downloaded(restoreImage: VZMacOSRestoreImage, progressHandler: @escaping ProgressHandler, completionHandler: @escaping CompletionHander) {
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { localURL, response, error in
            if let error = error {
                completionHandler(error.localizedDescription)
                return
            }
            if let localURL = localURL {
                try? FileManager.default.moveItem(at: localURL, to: URL.restoreImageURL)
            } else {
                completionHandler("Error: Failed to move downloaded restore image to \(URL.restoreImageURL)")
                return
            }

            completionHandler(nil) // no error
        }

        self.downloadTask = downloadTask
        progressObserver = downloadTask.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
            DispatchQueue.main.async {
                progressHandler(downloadTask.progress)
            }
        }
        downloadTask.resume()
    }

    fileprivate func loaded(restoreImage: VZMacOSRestoreImage, completionHandler: @escaping CompletionHander) {
        virtualMachineConfiguration = VirtualMacConfiguration()
        virtualMachineConfiguration?.getBestHardwareConfig(parameters: &parameters)

        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            completionHandler("Error: No supported hardware configuration available")
            return
        }

        parameters.cpuCountMin = mostFeaturefulSupportedConfiguration.minimumSupportedCPUCount
        parameters.memorySizeInGBMin = mostFeaturefulSupportedConfiguration.minimumSupportedMemorySize.bytesToGigabytes()

        if let errorMessage = writeParametersToDisk() {
            completionHandler(errorMessage)
            return
        }
        let version = restoreImage.operatingSystemVersion
        debugLog("Restore Image operating system version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion) (Build \(restoreImage.buildVersion))")
        debugLog("Host hardware model is supported: \(mostFeaturefulSupportedConfiguration.hardwareModel.isSupported)")
        debugLog("Parameters from disk image: \(parameters)")

        completionHandler(nil) // no error
    }

    fileprivate func restore(from restoreImage: VZMacOSRestoreImage) -> String? {
        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            return "Error: No supported hardware configuration available"
        }

        parameters.cpuCountMin = mostFeaturefulSupportedConfiguration.minimumSupportedCPUCount
        parameters.memorySizeInGBMin = mostFeaturefulSupportedConfiguration.minimumSupportedMemorySize.bytesToGigabytes()

        if let errorString = VirtualMac.createDiskImage(sizeInGB: parameters.diskSizeInGB) {
            return errorString
        }

        let virtualMacConfiguration = VirtualMacConfiguration()
        virtualMacConfiguration.create(using: &parameters, macHardwareModel: mostFeaturefulSupportedConfiguration.hardwareModel)

        do {
            try virtualMacConfiguration.validate()
            virtualMachineConfiguration = virtualMacConfiguration
        } catch {
            return "Error: Failed to validate virtual machine configuration during install"
        }

        return nil
    }

    fileprivate func startInstall(ipswURL: URL, virtualMacConfiguration: VirtualMacConfiguration, delegate: VZVirtualMachineDelegate, progressHandler: @escaping ProgressHandler, completionHandler: @escaping InstallCompletionHander) {
        self.virtualMachineConfiguration = virtualMacConfiguration
        guard let virtualMachine = createVirtualMachine(delegate: delegate) else {
            completionHandler("Error: Could not create virtual machine for install", nil)
            return
        }

        DispatchQueue.main.async {
            let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: ipswURL)

            installer.install { result in
                switch result {
                    case .success:
                        debugLog("Install finished")
                        self.stop(virtualMachine: virtualMachine, completionHandler: completionHandler)
                    case .failure(let error):
                        completionHandler("Error: Install failed: \(error)", nil)
                }
            }

            self.progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                progressHandler(installer.progress)
            }
        }
    }

    fileprivate func createBundle() -> String? {
        if FileManager.default.fileExists(atPath: URL.vmBundlePath) {
            return nil // already exists
        }

        let bundleFileDescriptor = mkdir(URL.vmBundlePath, S_IRWXU | S_IRWXG | S_IRWXO)
        if bundleFileDescriptor == -1 {
            if errno == EEXIST {
                return "Error: Failed to create VM bundle: the base directory already exists"
            }
            return "Error: Failed to create VM bundle"
        }

        let result = close(bundleFileDescriptor)
        if result != 0 {
            debugLog("Error: Failed to close VM bundle (\(result))")
        }

        return nil // no error
    }

    static func createDiskImage(sizeInGB: UInt64) -> String? {
        let diskFd = open(URL.diskImageURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskFd == -1 {
            return "Error: Cannot create disk image"
        }

        let diskSize = sizeInGB.gigabytesToBytes()
        var result = ftruncate(diskFd, Int64(diskSize))
        if result != 0 {
            return "Error: Expanding disk image failed"
        }

        result = close(diskFd)
        if result != 0 {
            return "Error: Failed to close the disk image"
        }

        return nil // no error
    }
}

#endif
