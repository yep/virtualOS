//
//  MacPlatformConfiguration.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import Virtualization
import OSLog

#if arch(arm64)

final class MacPlatformConfiguration: VZMacPlatformConfiguration {
    var versionString: String?
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")
    
    static func read(fromBundleURL bundleURL: URL) -> VZMacPlatformConfiguration? {
        let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")
        
        let macPlatformConfiguration = MacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: bundleURL.auxiliaryStorageURL)
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage

        guard let hardwareModelData = try? Data(contentsOf: bundleURL.hardwareModelURL) else {
            logger.log(level: .default, "Error: Failed to retrieve hardware model data")
            return nil
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            logger.log(level: .default, "Error: Failed to create hardware model")
            return nil
        }

        if !hardwareModel.isSupported {
            logger.log(level: .default, "Error: The hardware model is not supported on the current host")
            return nil
        }
        macPlatformConfiguration.hardwareModel = hardwareModel

        guard let machineIdentifierData = try? Data(contentsOf: bundleURL.machineIdentifierURL) else {
            logger.log(level: .default, "Error: Failed to retrieve machine identifier data.")
            return nil
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            logger.log(level: .default, "Error: Failed to create machine identifier.")
            return nil
        }
        macPlatformConfiguration.machineIdentifier = machineIdentifier
        
        return macPlatformConfiguration
    }
    
    static func createDefault(fromRestoreImage restoreImage: VZMacOSRestoreImage, versionString: inout String, bundleURL: URL) -> VZMacPlatformConfiguration? {
        let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")
        let macPlatformConfiguration = MacPlatformConfiguration()
        
        versionString = restoreImage.operatingSystemVersionString
        let versionString = versionString
        logger.log(level: .default, "restore image operating system version: \(versionString)")

        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            logger.log(level: .default, "restore image for macOS version \(versionString) is not supported on this machine")
            return nil
        }
        guard mostFeaturefulSupportedConfiguration.hardwareModel.isSupported else {
            logger.log(level: .default, "hardware model required by restore image for macOS version \(versionString) is not supported on this machine")
            return macPlatformConfiguration
        }
        
        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: URL.baseURL.auxiliaryStorageURL)
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
        
        guard let macPlatformConfiguration = macPlatformConfiguration.createPlatformConfiguration(macHardwareModel: mostFeaturefulSupportedConfiguration.hardwareModel, bundleURL: bundleURL) else {
            return nil
        }
        
        var vmParameters = VMParameters()
        vmParameters.cpuCountMin = mostFeaturefulSupportedConfiguration.minimumSupportedCPUCount
        vmParameters.memorySizeInGBMin = mostFeaturefulSupportedConfiguration.minimumSupportedMemorySize.bytesToGigabytes()
        
        return macPlatformConfiguration
    }
    
    fileprivate func createPlatformConfiguration(macHardwareModel: VZMacHardwareModel, bundleURL: URL) -> VZMacPlatformConfiguration? {
        let platformConfiguration = VZMacPlatformConfiguration()
        platformConfiguration.hardwareModel = macHardwareModel

        do {
            platformConfiguration.auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: bundleURL.auxiliaryStorageURL, hardwareModel: macHardwareModel, options: [.allowOverwrite]
            )
        } catch {
            logger.log(level: .default, "Error: could not create auxiliary storage device")
            return nil
        }

        do {
            try platformConfiguration.hardwareModel.dataRepresentation.write(to: bundleURL.hardwareModelURL)
            try platformConfiguration.machineIdentifier.dataRepresentation.write(to: bundleURL.machineIdentifierURL)
        } catch {
            logger.log(level: .default, "could store platform information to disk")
            return nil
        }

        return platformConfiguration // success
    }
}

#endif
