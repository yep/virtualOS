//
//  MacPlatformConfiguration.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Virtualization
import OSLog

#if arch(arm64)

final class MacPlatformConfiguration: VZMacPlatformConfiguration {
    var versionString: String?
    
    static func read(fromBundleURL bundleURL: URL) -> VZMacPlatformConfiguration? {        
        let macPlatformConfiguration = MacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: bundleURL.auxiliaryStorageURL)
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage

        guard let hardwareModelData = try? Data(contentsOf: bundleURL.hardwareModelURL) else {
            Logger.shared.log(level: .default, "Error: Failed to retrieve hardware model data")
            return nil
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            Logger.shared.log(level: .default, "Error: Failed to create hardware model")
            return nil
        }

        if !hardwareModel.isSupported {
            Logger.shared.log(level: .default, "Error: The hardware model is not supported on the current host")
            return nil
        }
        macPlatformConfiguration.hardwareModel = hardwareModel

        guard let machineIdentifierData = try? Data(contentsOf: bundleURL.machineIdentifierURL) else {
            Logger.shared.log(level: .default, "Error: Failed to retrieve machine identifier data.")
            return nil
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            Logger.shared.log(level: .default, "Error: Failed to create machine identifier.")
            return nil
        }
        macPlatformConfiguration.machineIdentifier = machineIdentifier
        
        return macPlatformConfiguration
    }
    
    static func createDefault(fromRestoreImage restoreImage: VZMacOSRestoreImage, versionString: inout String, bundleURL: URL) -> VZMacPlatformConfiguration? {
        let macPlatformConfiguration = MacPlatformConfiguration()
        
        versionString = restoreImage.operatingSystemVersionString
        let versionString = versionString
        Logger.shared.log(level: .default, "restore image version: \(versionString)")

        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            Logger.shared.log(level: .default, "restore image for macOS version \(versionString) is not supported on this machine")
            return nil
        }
        guard mostFeaturefulSupportedConfiguration.hardwareModel.isSupported else {
            Logger.shared.log(level: .default, "hardware model required by restore image for macOS version \(versionString) is not supported on this machine")
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
        } catch let error {
            Logger.shared.log(level: .default, "Error: could not create auxiliary storage device: \(error)")
            return nil
        }

        do {
            try platformConfiguration.hardwareModel.dataRepresentation.write(to: bundleURL.hardwareModelURL)
            try platformConfiguration.machineIdentifier.dataRepresentation.write(to: bundleURL.machineIdentifierURL)
        } catch {
            Logger.shared.log(level: .default, "could store platform information to disk")
            return nil
        }

        return platformConfiguration // success
    }
}

#endif
