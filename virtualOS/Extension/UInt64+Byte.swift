//
//  UInt+Byte.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

extension UInt64 {
    func bytesToGigabytes() -> UInt64 {
        return self / (1024 * 1024 * 1024)
    }

    func gigabytesToBytes() -> UInt64 {
        return self * 1024 * 1024 * 1024
    }
}
