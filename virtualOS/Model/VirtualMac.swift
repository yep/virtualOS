//
//  VirtualMac.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

#if arch(arm64)

import Virtualization
import Combine

final class VirtualMac: ObservableObject {
    struct Parameters: Codable {
        init() {}
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            cpuCount          = try container.decode(Int.self, forKey: .cpuCount)
            cpuCountMin       = try container.decode(Int.self, forKey: .cpuCountMin)
            cpuCountMax       = try container.decode(Int.self, forKey: .cpuCountMax)
            diskSizeInGB      = try container.decode(UInt64.self, forKey: .diskSizeInGB)
            memorySizeInGB    = try container.decode(UInt64.self, forKey: .memorySizeInGB)
            memorySizeInGBMin = try container.decode(UInt64.self, forKey: .memorySizeInGBMin)
            memorySizeInGBMax = try container.decode(UInt64.self, forKey: .memorySizeInGBMax)
            useMainScreenSize = try container.decodeIfPresent(Bool.self, forKey: .useMainScreenSize) ?? false // optional
            screenWidth       = try container.decode(Int.self, forKey: .screenWidth)
            screenHeight      = try container.decode(Int.self, forKey: .screenHeight)
            pixelsPerInch     = try container.decode(Int.self, forKey: .pixelsPerInch)
            microphoneEnabled = try container.decode(Bool.self, forKey: .microphoneEnabled)
            sharedFolder      = try container.decodeIfPresent(Data.self, forKey: .sharedFolder) ?? nil // optional
            macAddress        = try container.decodeIfPresent(String.self, forKey: .macAddress) ?? VZMACAddress.randomLocallyAdministered().string // optional
        }
        
        var cpuCount = 1
        var cpuCountMin = 1
        var cpuCountMax = 2
        var diskSizeInGB: UInt64 = UInt64(UserDefaults.standard.diskSize)
        var memorySizeInGB: UInt64 = 1
        var memorySizeInGBMin: UInt64 = 1
        var memorySizeInGBMax: UInt64 = 2
        var useMainScreenSize = false
        var screenWidth = 1500
        var screenHeight = 900
        var pixelsPerInch = 250
        var microphoneEnabled = false
        var sharedFolder: Data?
        var macAddress = VZMACAddress.randomLocallyAdministered().string
    }

    typealias InstallCompletionHander = (String?, VZVirtualMachine?) -> Void    

    var parameters = Parameters()
    var versionString = "(unknown)"
    var virtualMachineConfiguration: VirtualMacConfiguration?
    var progressObserverCancellable: Cancellable?
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

    func install(delegate: VZVirtualMachineDelegate, customRestoreImageURL: URL?, progressHandler: @escaping ProgressHandler, completionHandler: @escaping InstallCompletionHander) {
        loadParametersFromRestoreImage(customRestoreImageURL: customRestoreImageURL) { (errorString: String?) in
            if let errorString = errorString {
                completionHandler(errorString, nil)
            } else {
                self.loadAndInstallRestoreImage(delegate: delegate, customRestoreImageURL: customRestoreImageURL, progressHandler: progressHandler, completionHandler: completionHandler)
            }
        }
    }

    func loadParametersFromRestoreImage(customRestoreImageURL: URL?, completionHandler: @escaping CompletionHander) {
        if let errorString = createBundle() {
            completionHandler(errorString)
            return
        }
        
        var restoreImageURL = URL.restoreImageURL
        if let customRestoreImageURL = customRestoreImageURL {
            restoreImageURL = customRestoreImageURL
        }
         
        VZMacOSRestoreImage.load(from: restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
                case .success(let restoreImage):
                    self.didLoad(restoreImage: restoreImage, completionHandler: completionHandler)
                case .failure(let failure):
                    completionHandler("Error: Could not read restore image: \(failure)")
            }
        }
    }

    func loadAndInstallRestoreImage(delegate: VZVirtualMachineDelegate, customRestoreImageURL: URL?, progressHandler: @escaping ProgressHandler, completionHandler: @escaping InstallCompletionHander)  {
        var restoreImageURL = URL.restoreImageURL
        if let customRestoreImageURL = customRestoreImageURL {
            restoreImageURL = customRestoreImageURL
        }

        VZMacOSRestoreImage.load(from: restoreImageURL) { (result: Result<Virtualization.VZMacOSRestoreImage, Error>) in
            switch result {
                case .success(let restoreImage):
                    if let errorString = self.restore(from: restoreImage) {
                        completionHandler(errorString, nil)
                    } else if let virtualMachineConfiguration = self.virtualMachineConfiguration {
                        self.startInstall(ipswURL: restoreImageURL, virtualMacConfiguration: virtualMachineConfiguration, delegate: delegate, progressHandler: progressHandler, completionHandler: completionHandler)
                    } else {
                        completionHandler("Error: No virtual machine configuration found", nil)
                    }
                case .failure(let failure):
                    completionHandler("Error: Loading restore image failed: \(failure)", nil)
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
            virtualOSApp.debugLog("Error: \(error.localizedDescription)")
            return nil
        }

        if let errorString = writeParametersToDisk() {
            virtualOSApp.debugLog(errorString)
            return nil
        }
        
        let virtualMachine = VZVirtualMachine(configuration: virtualMacConfiguration, queue: .main)
        virtualMachine.delegate = delegate

        virtualOSApp.debugLog("Using \(virtualMacConfiguration.cpuCount) cores, \(virtualMacConfiguration.memorySize.bytesToGigabytes()) GB RAM, screen size \(parameters.screenWidth)x\(parameters.screenHeight) px at \(parameters.pixelsPerInch) ppi, shared folder: \(Bookmark.startAccess(data: parameters.sharedFolder, forType: .sharedFolder)?.absoluteString ?? "none")")
        
        return virtualMachine
    }

    func stop(virtualMachine: VZVirtualMachine, completionHandler: @escaping InstallCompletionHander) {
        virtualMachine.stop(completionHandler: { (error: Error?) in
            if let error = error {
                virtualOSApp.debugLog("Error while stopping: \(error)")
                completionHandler(error.localizedDescription, nil)
            } else {
                virtualOSApp.debugLog("Stopped")
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
        virtualOSApp.debugLog("Attempting to download latest available restore image")
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    completionHandler(error.localizedDescription)
                case let .success(restoreImage):
                    download(restoreImage: restoreImage, progressHandler: progressHandler, completionHandler: completionHandler)
            }
        }
    }

    fileprivate func download(restoreImage: VZMacOSRestoreImage, progressHandler: @escaping ProgressHandler, completionHandler: @escaping CompletionHander) {
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
        
        progressObserverCancellable = downloadTask.progress.publisher(for: \.fractionCompleted)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink() { (progress) in
                progressHandler(downloadTask.progress)
            }
        downloadTask.resume()
    }

    fileprivate func didLoad(restoreImage: VZMacOSRestoreImage, completionHandler: @escaping CompletionHander) {
        let (_, errorString) = readSupportedConfiguration(from: restoreImage)
        if errorString != nil {
            completionHandler(errorString)
            return
        }

        virtualMachineConfiguration = VirtualMacConfiguration()
        virtualMachineConfiguration?.setDefault(parameters: &parameters)
        virtualOSApp.debugLog("Parameters from restore image: \(parameters)")

        if let errorString = writeParametersToDisk() {
            completionHandler(errorString)
            return
        }

        completionHandler(nil) // no error
    }

    fileprivate func restore(from restoreImage: VZMacOSRestoreImage) -> String? {
        let (mostFeaturefulSupportedConfiguration, errorString) = readSupportedConfiguration(from: restoreImage)
        guard let mostFeaturefulSupportedConfiguration = mostFeaturefulSupportedConfiguration else {
            return errorString
        }
        
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
    
    fileprivate func readSupportedConfiguration(from restoreImage: VZMacOSRestoreImage) -> (VZMacOSConfigurationRequirements?, String?) {
        let version = restoreImage.operatingSystemVersion
        versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion) (Build \(restoreImage.buildVersion))"
        virtualOSApp.debugLog("Restore image operating system version: \(versionString)")

        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            return (nil, "Error: Restore image for macOS version \(versionString) is not supported on this machine")
        }
        guard mostFeaturefulSupportedConfiguration.hardwareModel.isSupported else {
            return (nil, "Error: Hardware model required by restore image for macOS version \(versionString) is not supported on this machine")
        }

        parameters.cpuCountMin = mostFeaturefulSupportedConfiguration.minimumSupportedCPUCount
        parameters.memorySizeInGBMin = mostFeaturefulSupportedConfiguration.minimumSupportedMemorySize.bytesToGigabytes()

        return (mostFeaturefulSupportedConfiguration, nil) // no error
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
                        virtualOSApp.debugLog("Install finished")
                        self.stop(virtualMachine: virtualMachine, completionHandler: completionHandler)
                    case .failure(let error):
                        self.progressObserverCancellable?.cancel()
                        completionHandler("Error: Install failed: \(error).\nPlease select `Delete Virtual Machine` and `Delete Restore Image` from the file menu or use a different restore image and try again.", nil)
                }
            }

            self.progressObserverCancellable = installer.progress.publisher(for: \.fractionCompleted)
                .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
                .sink() { (progress) in
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
                return "Failed to create VM bundle: the base directory already exists"
            }
            return "Failed to create VM bundle at \(URL.vmBundlePath) (error number \(errno))"
        }

        let result = close(bundleFileDescriptor)
        if result != 0 {
            virtualOSApp.debugLog("Failed to close VM bundle (\(result))")
        }

        return nil // no error
    }

    static func createDiskImage(sizeInGB: UInt64) -> String? {
        let diskImageFileDescriptor = open(URL.diskImageURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskImageFileDescriptor == -1 {
            return "Error: Cannot create disk image"
        }

        let diskSize = sizeInGB.gigabytesToBytes()
        var result = ftruncate(diskImageFileDescriptor, Int64(diskSize))
        if result != 0 {
            return "Error: Expanding disk image failed"
        }

        result = close(diskImageFileDescriptor)
        if result != 0 {
            return "Error: Failed to close the disk image"
        }

        return nil // no error
    }
}

#endif
