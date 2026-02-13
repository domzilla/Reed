//
//  ParsedAuthor.swift
//  RDParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ParsedAuthor: Hashable, Codable, Sendable {
    let name: String?
    let url: String?
    let avatarURL: String?
    let emailAddress: String?

    init(name: String?, url: String?, avatarURL: String?, emailAddress: String?) {
        self.name = name
        self.url = url
        self.avatarURL = avatarURL
        self.emailAddress = emailAddress
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        if let name {
            hasher.combine(name)
        } else if let url {
            hasher.combine(url)
        } else if let emailAddress {
            hasher.combine(emailAddress)
        } else if let avatarURL {
            hasher.combine(avatarURL)
        } else {
            hasher.combine("")
        }
    }
}
