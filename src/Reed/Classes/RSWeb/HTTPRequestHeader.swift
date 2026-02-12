//
//  HTTPRequestHeader.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated enum HTTPRequestHeader {
    static let userAgent = "User-Agent"
    static let authorization = "Authorization"
    static let contentType = "Content-Type"

    // Conditional GET

    static let ifModifiedSince = "If-Modified-Since"
    static let ifNoneMatch = "If-None-Match" // Etag
}
