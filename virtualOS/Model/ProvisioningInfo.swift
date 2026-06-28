//
//  ProvisioningInfo.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

struct ProvisioningInfo: Codable {
    let fullName: String
    let username: String
    let password: String
    let autoLogin: Bool
    let remoteLogin: Bool
}
