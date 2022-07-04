//
//  URL+Paths.swift
//  virtualOS
//

import Foundation

extension URL {
    static let basePath             = NSHomeDirectory() + "/Documents"
    static let restoreImageURL      = URL(fileURLWithPath: basePath + "/RestoreImage.ipsw")

    static let vmBundlePath         = basePath + "/virtualOS.bundle/"
    static let vmBundleURL          = URL(fileURLWithPath: vmBundlePath)
    static let diskImageURL         = URL(fileURLWithPath: vmBundlePath + "Disk.img")
    static let auxiliaryStorageURL  = URL(fileURLWithPath: vmBundlePath + "AuxiliaryStorage")
    static let machineIdentifierURL = URL(fileURLWithPath: vmBundlePath + "MachineIdentifier")
    static let hardwareModelURL     = URL(fileURLWithPath: vmBundlePath + "HardwareModel")
    static let parametersURL        = URL(fileURLWithPath: vmBundlePath + "Parameters.txt")
}

