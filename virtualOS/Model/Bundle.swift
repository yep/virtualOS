//
//  Bundle.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Foundation

struct VMBundle: Identifiable, Hashable {
    var id: String {
        return url.path
    }
    var url: URL
    var name: String {
        return url.lastPathComponent.replacingOccurrences(of: ".bundle", with: "")
    }
}
