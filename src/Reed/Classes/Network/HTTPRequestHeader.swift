//
//  HTTPRequestHeader.swift
//  Web
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated enum HTTPRequestHeader {
    static let userAgent = "User-Agent"

    // Conditional GET

    static let ifModifiedSince = "If-Modified-Since"
    static let ifNoneMatch = "If-None-Match" // Etag
}

nonisolated struct HTTPResponseHeader: Sendable {
    // Conditional GET
    static let lastModified = "Last-Modified"
    static let etag = "Etag"

    static let cacheControl = "Cache-Control"
    static let retryAfter = "Retry-After"
}
