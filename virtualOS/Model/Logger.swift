//
//  Logger.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import OSLog

extension Logger {
    static let shared = Logger.init(subsystem: "com.github.virtualOS", category: "log")
}
