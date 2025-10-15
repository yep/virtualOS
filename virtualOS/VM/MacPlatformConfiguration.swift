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
    
    static func read(fromBundleURL bundleURL: URL) -> MacPlatformConfigurationResult {
        let macPlatformConfiguration = MacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: bundleURL.auxiliaryStorageURL)
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage

        guard let hardwareModelData = try? Data(contentsOf: bundleURL.hardwareModelURL) else {
            return MacPlatformConfigurationResult(errorMessage: "Error: Failed to retrieve hardware model data")
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            return MacPlatformConfigurationResult(errorMessage: "Error: Failed to create hardware model")
        }

        if !hardwareModel.isSupported {
            return MacPlatformConfigurationResult(errorMessage: "Error: The hardware model is not supported on the current host")
        }
        macPlatformConfiguration.hardwareModel = hardwareModel

        guard let machineIdentifierData = try? Data(contentsOf: bundleURL.machineIdentifierURL) else {
            return MacPlatformConfigurationResult(errorMessage: "Error: Failed to retrieve machine identifier data.")
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            return MacPlatformConfigurationResult(errorMessage: "Error: Failed to create machine identifier.")
        }
        macPlatformConfiguration.machineIdentifier = machineIdentifier
        
        return MacPlatformConfigurationResult(macPlatformConfiguration: macPlatformConfiguration)
    }
    
    static func createDefault(fromRestoreImage restoreImage: VZMacOSRestoreImage, versionString: inout String, bundleURL: URL) -> MacPlatformConfigurationResult {
        versionString = restoreImage.operatingSystemVersionString
        let versionString = versionString
        Logger.shared.log(level: .default, "restore image version: \(versionString)")

        guard let mostFeaturefulSupportedConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            return MacPlatformConfigurationResult(errorMessage: "Restore image for macOS version \(versionString) is not supported on this machine.")
        }
        guard mostFeaturefulSupportedConfiguration.hardwareModel.isSupported else {
            return MacPlatformConfigurationResult(errorMessage: "Hardware model required by restore image for macOS version \(versionString) is not supported on this machine.")
        }
        
        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: URL.baseURL.auxiliaryStorageURL)
        let macPlatformConfiguration = MacPlatformConfiguration()
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
        
        let macPlatformConfigurationResult = macPlatformConfiguration.createPlatformConfiguration(macHardwareModel: mostFeaturefulSupportedConfiguration.hardwareModel, bundleURL: bundleURL)
        if case .failure(_) = macPlatformConfigurationResult {
            return macPlatformConfigurationResult
        }
        
        var vmParameters = VMParameters()
        vmParameters.cpuCountMin = mostFeaturefulSupportedConfiguration.minimumSupportedCPUCount
        vmParameters.memorySizeInGBMin = mostFeaturefulSupportedConfiguration.minimumSupportedMemorySize.bytesToGigabytes()

        return macPlatformConfigurationResult
    }
    
    fileprivate func createPlatformConfiguration(macHardwareModel: VZMacHardwareModel, bundleURL: URL) -> MacPlatformConfigurationResult {
        let platformConfiguration = VZMacPlatformConfiguration()
        platformConfiguration.hardwareModel = macHardwareModel
        
        do {
            platformConfiguration.auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: bundleURL.auxiliaryStorageURL, hardwareModel: macHardwareModel, options: [.allowOverwrite]
            )
        } catch let error {
            return MacPlatformConfigurationResult(errorMessage: "Could not create auxiliary storage device: \(error).")
        }

        do {
            try platformConfiguration.hardwareModel.dataRepresentation.write(to: bundleURL.hardwareModelURL)
            try platformConfiguration.machineIdentifier.dataRepresentation.write(to: bundleURL.machineIdentifierURL)
        } catch {
            return MacPlatformConfigurationResult(errorMessage: "Could store platform information to disk.")
        }

        return MacPlatformConfigurationResult(macPlatformConfiguration: platformConfiguration) // success
    }
}

#endif
