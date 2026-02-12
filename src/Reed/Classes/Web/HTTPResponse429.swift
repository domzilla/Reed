//
//  HTTPResponse429.swift
//  Web
//
//  Created by Brent Simmons on 11/24/24.
//

import Foundation

// 429 Too Many Requests

struct HTTPResponse429 {
    let url: URL
    let host: String // lowercased
    let dateCreated: Date
    let retryAfter: TimeInterval

    var resumeDate: Date {
        self.dateCreated + TimeInterval(self.retryAfter)
    }

    var canResume: Bool {
        Date() >= self.resumeDate
    }

    init?(url: URL, retryAfter: TimeInterval) {
        guard let host = url.host() else {
            return nil
        }

        self.url = url
        self.host = host.lowercased()
        self.retryAfter = retryAfter
        self.dateCreated = Date()
    }
}
