//
//  VirtualMachineConfiguration.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

import Foundation
import Virtualization
import AVFoundation

final class VirtualMacConfiguration: VZVirtualMachineConfiguration {
    struct VirtualMachineParameters {
        var hardwareModel: VZMacHardwareModel
        var machineIdentifier: VZMacMachineIdentifier
        var screenWidth: Int
        var screenHeight: Int
        var pixelsPerInch: Int
        var storageDeviceURL: URL
        var memorySizeInGB: UInt64
        var microphoneEnabled: Bool
        var auxiliaryStorageURL: URL
    }

    fileprivate(set) var microphoneEnabled = false
    var memorySizeInGB: UInt64 {
        get {
            return self.memorySize / 1024
        }
        set {
            self.memorySize = newValue * 1024
        }
    }

    override init() {
        super.init()

        pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        networkDevices  = [VZVirtioNetworkDeviceConfiguration()]
        entropyDevices  = [VZVirtioEntropyDeviceConfiguration()]
        bootLoader      = VZMacOSBootLoader()
        keyboards       = [VZUSBKeyboardConfiguration()]

        networkDevices.first?.attachment = VZNATNetworkDeviceAttachment()
    }

    func setup(parameters: VirtualMachineParameters) {
        microphoneEnabled = parameters.microphoneEnabled
        memorySizeInGB    = parameters.memorySizeInGB

        setupAudioDevice(parameters: parameters)
        setupGraphicsDevice(parameters: parameters)
        setupStorageDevice(parameters: parameters)
        setupAuxStorage(parameters: parameters)
    }

    fileprivate func setupPlatform(parameters: VirtualMachineParameters) {
        let platformConfiguration = VZMacPlatformConfiguration()
        platformConfiguration.hardwareModel = parameters.hardwareModel
        platformConfiguration.machineIdentifier = parameters.machineIdentifier

        platformConfiguration.auxiliaryStorage = try? VZMacAuxiliaryStorage(
            creatingStorageAt: parameters.auxiliaryStorageURL,
            hardwareModel: parameters.hardwareModel,
            options: [.allowOverwrite]
        )

        platform = platformConfiguration
    }

    fileprivate func setupAudioDevice(parameters: VirtualMachineParameters) {
        let audioDevice = VZVirtioSoundDeviceConfiguration()
        let soundDeviceOutputStreamConfiguration = VZVirtioSoundDeviceOutputStreamConfiguration()
        soundDeviceOutputStreamConfiguration.sink = VZHostAudioOutputStreamSink()
        audioDevice.streams.append(soundDeviceOutputStreamConfiguration)

        if microphoneEnabled {
            AVCaptureDevice.requestAccess(for: .audio) { (granted: Bool) in
                print("microphone request granted: \(granted)")
            }
            let soundDeviceInputStreamConfiguration = VZVirtioSoundDeviceInputStreamConfiguration()
            soundDeviceInputStreamConfiguration.source = VZHostAudioInputStreamSource()
            audioDevice.streams.append(soundDeviceInputStreamConfiguration)
        }

        audioDevices = [audioDevice]
    }

    fileprivate func setupGraphicsDevice(parameters: VirtualMachineParameters) {
        let graphicsDevice = VZMacGraphicsDeviceConfiguration()
        graphicsDevice.displays = [VZMacGraphicsDisplayConfiguration(
            widthInPixels: parameters.screenWidth,
            heightInPixels: parameters.screenHeight,
            pixelsPerInch: parameters.pixelsPerInch
        )]
        graphicsDevices = [graphicsDevice]
    }

    fileprivate func setupStorageDevice(parameters: VirtualMachineParameters) {
        if let diskImageStorageDeviceAttachment = try? VZDiskImageStorageDeviceAttachment(url: parameters.storageDeviceURL, readOnly: false) {
            let blockDeviceConfiguration = VZVirtioBlockDeviceConfiguration(attachment: diskImageStorageDeviceAttachment)
            storageDevices = [blockDeviceConfiguration]
        }
    }
}
