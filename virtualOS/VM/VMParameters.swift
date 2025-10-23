//
//  VMParameters.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

#if arch(arm64)

import Virtualization
import OSLog

struct VMParameters: Codable {
    var installFinished: Bool? = false
    var cpuCount = 1
    var cpuCountMin = 1
    var cpuCountMax = 2
    var diskSizeInGB: UInt64 = UInt64(UserDefaults.standard.diskSize)
    var memorySizeInGB: UInt64 = 1
    var memorySizeInGBMin: UInt64 = 1
    var memorySizeInGBMax: UInt64 = 2
    var useMainScreenSize = true
    var screenWidth = 1500
    var screenHeight = 900
    var pixelsPerInch = 250
    var microphoneEnabled = true
    var sharedFolderURL: URL?
    var sharedFolderData: Data?
    var macAddress = VZMACAddress.randomLocallyAdministered().string
    var version = ""
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        installFinished   = try container.decodeIfPresent(Bool.self, forKey: .installFinished) ?? true // optional
        cpuCount          = try container.decode(Int.self, forKey: .cpuCount)
        cpuCountMin       = try container.decode(Int.self, forKey: .cpuCountMin)
        cpuCountMax       = try container.decode(Int.self, forKey: .cpuCountMax)
        diskSizeInGB      = try container.decode(UInt64.self, forKey: .diskSizeInGB)
        memorySizeInGB    = try container.decode(UInt64.self, forKey: .memorySizeInGB)
        memorySizeInGBMin = try container.decode(UInt64.self, forKey: .memorySizeInGBMin)
        memorySizeInGBMax = try container.decode(UInt64.self, forKey: .memorySizeInGBMax)
        useMainScreenSize = try container.decodeIfPresent(Bool.self, forKey: .useMainScreenSize) ?? true // optional
        screenWidth       = try container.decode(Int.self, forKey: .screenWidth)
        screenHeight      = try container.decode(Int.self, forKey: .screenHeight)
        pixelsPerInch     = try container.decode(Int.self, forKey: .pixelsPerInch)
        microphoneEnabled = try container.decode(Bool.self, forKey: .microphoneEnabled)
        sharedFolderURL   = try container.decodeIfPresent(URL.self, forKey: .sharedFolderURL) ?? nil // optional
        sharedFolderData  = try container.decodeIfPresent(Data.self, forKey: .sharedFolderData) ?? nil // optional
        macAddress        = try container.decodeIfPresent(String.self, forKey: .macAddress) ?? VZMACAddress.randomLocallyAdministered().string // optional
        version           = try container.decodeIfPresent(String.self, forKey: .version) ?? "" // optional

    }
    
    static func readFrom(url: URL) -> VMParameters? {
        let decoder = JSONDecoder()
        do {
            let json = try Data.init(contentsOf: url.appendingPathComponent("Parameters.txt", conformingTo: .text))
            return try decoder.decode(VMParameters.self, from: json)
        } catch (let error) {
            Logger.shared.log(level: .default, "failed to read parameters from \(url): \(error)")
        }
        return nil
    }
    
    func writeToDisk(bundleURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(self)
            if let json = String(data: jsonData, encoding: .utf8) {
                try json.write(to: bundleURL.parametersURL, atomically: true, encoding: String.Encoding.utf8)
            }
        } catch {
            Logger.shared.log(level: .default, "failed to write current CPU and RAM configuration to disk")
        }
    }
}

#endif

