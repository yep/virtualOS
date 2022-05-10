//
//  UInt+Byte.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
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
