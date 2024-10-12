//
//  Bundle.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

import Foundation

struct VMBundle: Identifiable, Hashable {
    var id: String {
        return url.absoluteString
    }
    var url: URL
    var name: String {
        return url.lastPathComponent.replacingOccurrences(of: ".bundle", with: "")
    }
}
