//
//  VirtualMacConfiguration.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

#if arch(arm64)

import Virtualization
import AVFoundation

final class VirtualMacConfiguration: VZVirtualMachineConfiguration {
    fileprivate(set) var machineIdentifier = VZMacMachineIdentifier()

    func create(using parameters: inout VirtualMac.Parameters, macHardwareModel: VZMacHardwareModel) {
        if !configurePlatform(parameters: parameters, macHardwareModel: macHardwareModel) {
            return // error
        }
        configure(with: &parameters)
    }

    func readFromDisk(using parameters: inout VirtualMac.Parameters) {
        let (errorString, platform) = readPlaformFromDisk()
        if let errorString = errorString {
            virtualOSApp.debugLog(errorString)
        } else if let platform = platform {
            self.platform = platform
            configure(with: &parameters)
        } else {
            virtualOSApp.debugLog("Error: Reading platform from disk failed")
        }
    }

    func setDefault(parameters: inout VirtualMac.Parameters) {
        let cpuCountMax = computeCPUCount()
        let bytesMax = VZVirtualMachineConfiguration.maximumAllowedMemorySize
        let bytesMaxMinus2GB = bytesMax - UInt64(2).gigabytesToBytes() // substract 2 GB

        cpuCount   = cpuCountMax - 1 // substract one core
        memorySize = bytesMaxMinus2GB

        parameters.cpuCount = cpuCount
        parameters.cpuCountMax = cpuCountMax
        parameters.memorySizeInGB = memorySize.bytesToGigabytes()
        parameters.memorySizeInGBMax = bytesMax.bytesToGigabytes()
    }

    func configure(with parameters: inout VirtualMac.Parameters) {
        cpuCount        = parameters.cpuCount
        memorySize      = parameters.memorySizeInGB.gigabytesToBytes()
        pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        entropyDevices  = [VZVirtioEntropyDeviceConfiguration()]
        bootLoader      = VZMacOSBootLoader()
        keyboards       = [VZUSBKeyboardConfiguration()]

        configureAudioDevice(parameters: parameters)
        configureGraphicsDevice(parameters: parameters)
        configureStorageDevice(parameters: parameters)
        configureNetworkDevices()
    }

    // MARK: - Private

    fileprivate func configurePlatform(parameters: VirtualMac.Parameters, macHardwareModel: VZMacHardwareModel) -> Bool {
        let platformConfiguration = VZMacPlatformConfiguration()
        platformConfiguration.hardwareModel = macHardwareModel

        do {
            platformConfiguration.auxiliaryStorage = try VZMacAuxiliaryStorage(
                creatingStorageAt: URL.auxiliaryStorageURL,
                hardwareModel: macHardwareModel,
                options: [.allowOverwrite]
            )
        } catch {
            virtualOSApp.debugLog("Error: could not create auxiliary storage device")
            return false
        }

        do {
            try platformConfiguration.hardwareModel.dataRepresentation.write(to: URL.hardwareModelURL)
            try platformConfiguration.machineIdentifier.dataRepresentation.write(to: URL.machineIdentifierURL)
        } catch {
            virtualOSApp.debugLog("Error: could store platform information to disk")
            return false
        }

        platform = platformConfiguration
        return true // success
    }

    fileprivate func configureNetworkDevices() {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        networkDevices = [networkDevice]
    }

    fileprivate func configureAudioDevice(parameters: VirtualMac.Parameters) {
        let audioDevice = VZVirtioSoundDeviceConfiguration()

        if parameters.microphoneEnabled {
            AVCaptureDevice.requestAccess(for: .audio) { (granted: Bool) in
                virtualOSApp.debugLog("Microphone request granted: \(granted)")
            }

            let inputStreamConfiguration = VZVirtioSoundDeviceInputStreamConfiguration()
            inputStreamConfiguration.source = VZHostAudioInputStreamSource()
            audioDevice.streams.append(inputStreamConfiguration)
        }

        let outputStreamConfiguration = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStreamConfiguration.sink = VZHostAudioOutputStreamSink()
        audioDevice.streams.append(outputStreamConfiguration)

        audioDevices = [audioDevice]
    }

    fileprivate func configureGraphicsDevice(parameters: VirtualMac.Parameters) {
        let graphicsDevice = VZMacGraphicsDeviceConfiguration()
        graphicsDevice.displays = [VZMacGraphicsDisplayConfiguration(
            widthInPixels: parameters.screenWidth,
            heightInPixels: parameters.screenHeight,
            pixelsPerInch: parameters.pixelsPerInch
        )]
        graphicsDevices = [graphicsDevice]
    }

    fileprivate func configureStorageDevice(parameters: VirtualMac.Parameters) {
        if let diskImageStorageDeviceAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL.diskImageURL, readOnly: false) {
            let blockDeviceConfiguration = VZVirtioBlockDeviceConfiguration(attachment: diskImageStorageDeviceAttachment)
            storageDevices = [blockDeviceConfiguration]
        } else {
            virtualOSApp.debugLog("Error: could not create storage device")
        }
    }

    fileprivate func computeCPUCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }

    fileprivate func readPlaformFromDisk() -> (String?, VZMacPlatformConfiguration?) {
        let macPlatform = VZMacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: URL.auxiliaryStorageURL)
        macPlatform.auxiliaryStorage = auxiliaryStorage

        if !FileManager.default.fileExists(atPath: URL.vmBundlePath) {
            return ("Error: Missing virtual machine bundle at \(URL.vmBundlePath).", nil)
        }

        guard let hardwareModelData = try? Data(contentsOf: URL.hardwareModelURL) else {
            return ("Error: Failed to retrieve hardware model data", nil)
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            return ("Error: Failed to create hardware model", nil)
        }

        if !hardwareModel.isSupported {
            return ("Error: The hardware model is not supported on the current host", nil)
        }
        macPlatform.hardwareModel = hardwareModel

        guard let machineIdentifierData = try? Data(contentsOf: URL.machineIdentifierURL) else {
            return ("Error: Failed to retrieve machine identifier data.", nil)
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            return ("Error: Failed to create machine identifier.", nil)
        }
        macPlatform.machineIdentifier = machineIdentifier

        return (nil, macPlatform)
    }
}

#endif
