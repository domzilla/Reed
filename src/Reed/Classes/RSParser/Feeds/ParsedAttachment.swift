//
//  ParsedAttachment.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ParsedAttachment: Hashable, Sendable {
    let url: String
    let mimeType: String?
    let title: String?
    let sizeInBytes: Int?
    let durationInSeconds: Int?

    init?(url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {
        if url.isEmpty {
            return nil
        }

        self.url = url
        self.mimeType = mimeType
        self.title = title
        self.sizeInBytes = sizeInBytes
        self.durationInSeconds = durationInSeconds
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.url)
    }
}
