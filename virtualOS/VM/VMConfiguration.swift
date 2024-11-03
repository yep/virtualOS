//
//  VM.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

#if arch(arm64)

import Virtualization
import AVFoundation // for audio
import OSLog

final class VMConfiguration: VZVirtualMachineConfiguration {
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")

    func setup(parameters: VMParameters, macPlatformConfiguration: VZMacPlatformConfiguration, bundleURL: URL) {
        cpuCount        = parameters.cpuCount
        memorySize      = parameters.memorySizeInGB.gigabytesToBytes()
        pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        entropyDevices  = [VZVirtioEntropyDeviceConfiguration()]
        keyboards       = [VZUSBKeyboardConfiguration()]
        bootLoader      = VZMacOSBootLoader()
        
        configureAudioDevice(parameters: parameters)
        configureGraphicsDevice(parameters: parameters)
        configureStorageDevice(parameters: parameters, bundleURL: bundleURL)
        configureNetworkDevices(parameters: parameters)
        configureSharedFolder(parameters: parameters)
        configureClipboardSharing()
        configureUSB()

        platform = macPlatformConfiguration
    }
    
    func setDefault(parameters: inout VMParameters) {
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

    // MARK: - Private
        
    fileprivate func configureAudioDevice(parameters: VMParameters) {
        let audioDevice = VZVirtioSoundDeviceConfiguration()
        
        if parameters.microphoneEnabled {
            AVCaptureDevice.requestAccess(for: .audio) { (granted: Bool) in
                self.logger.log(level: .default, "microphone request granted: \(granted)")
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
    
    fileprivate func configureGraphicsDevice(parameters: VMParameters) {
        let graphicsDevice = VZMacGraphicsDeviceConfiguration()
        if parameters.useMainScreenSize, let mainScreen = NSScreen.main {
            graphicsDevice.displays = [VZMacGraphicsDisplayConfiguration(for: mainScreen, sizeInPoints: NSSize(width: parameters.screenWidth, height: parameters.screenHeight))]
        } else {
            graphicsDevice.displays = [VZMacGraphicsDisplayConfiguration(
                widthInPixels: parameters.screenWidth,
                heightInPixels: parameters.screenHeight,
                pixelsPerInch: parameters.pixelsPerInch
            )]
        }
        graphicsDevices = [graphicsDevice]
    }
    
    fileprivate func configureStorageDevice(parameters: VMParameters, bundleURL: URL) {
        let diskImageStorageDeviceAttachment: VZDiskImageStorageDeviceAttachment?
        do {
            diskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(url: bundleURL.diskImageURL, readOnly: false)
        } catch let error {
            logger.log(level: .default, "could not create storage device: \(error.localizedDescription)")
            return
        }
        
        if let diskImageStorageDeviceAttachment {
            let blockDeviceConfiguration = VZVirtioBlockDeviceConfiguration(attachment: diskImageStorageDeviceAttachment)
            storageDevices = [blockDeviceConfiguration]
        }

        if let diskImageStorageDeviceAttachment = try? VZDiskImageStorageDeviceAttachment(url: bundleURL.diskImageURL, readOnly: false) {
            let blockDeviceConfiguration = VZVirtioBlockDeviceConfiguration(attachment: diskImageStorageDeviceAttachment)
            storageDevices = [blockDeviceConfiguration]
        } else {
            logger.log(level: .default, "could not create storage device")
        }
    }
    
    fileprivate func configureNetworkDevices(parameters: VMParameters) {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        networkDevice.macAddress = VZMACAddress(string: parameters.macAddress) ?? .randomLocallyAdministered()
        networkDevices = [networkDevice]
    }

    fileprivate func configureSharedFolder(parameters: VMParameters) {
        guard let sharedFolderBookmarkData = Bookmark.startAccess(bookmarkData: parameters.sharedFolder) else {
            return
        }
                
        let sharedDirectory = VZSharedDirectory(url: sharedFolderBookmarkData, readOnly: false)
        let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
        let sharingConfiguration = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
        sharingConfiguration.share = singleDirectoryShare
        
        directorySharingDevices = [sharingConfiguration]
    }
    
    fileprivate func configureClipboardSharing() {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort
        
        consoleDevices.append(consoleDevice)
    }
    
    fileprivate func configureUSB() {
        let usbControllerConfiguration = VZXHCIControllerConfiguration()
        usbControllers = [usbControllerConfiguration]
    }
    
    fileprivate func computeCPUCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }
}

#endif
