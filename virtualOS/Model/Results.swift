//
//  Results.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import OSLog
import Virtualization

#if arch(arm64)

typealias RestoreResult = Result<Bool, RestoreError>
extension RestoreResult {
    init() {
        self = .success(true)
    }
    
    init(errorMessage: String) {
        Logger.shared.log(level: .default, "\(errorMessage)")
        self = .failure(.init(localizedDescription: errorMessage))
    }
}

typealias MacPlatformConfigurationResult = Result<VZMacPlatformConfiguration?, RestoreError>
extension MacPlatformConfigurationResult {
    init(macPlatformConfiguration: VZMacPlatformConfiguration) {
        self = .success(macPlatformConfiguration)
    }
    
    init(errorMessage: String) {
        Logger.shared.log(level: .default, "\(errorMessage)")
        self = .failure(.init(localizedDescription: errorMessage))
    }
}

#endif
