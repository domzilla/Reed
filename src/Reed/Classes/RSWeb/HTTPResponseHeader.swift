//
//  HTTPResponseHeader.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated struct HTTPResponseHeader: Sendable {
    static let contentType = "Content-Type"
    static let location = "Location"
    static let link = "Links"
    static let date = "Date"

    // Conditional GET. See:
    // http://fishbowl.pastiche.org/2002/10/21/http_conditional_get_for_rss_hackers/

    static let lastModified = "Last-Modified"
    // Changed to the canonical case for lookups against a case sensitive dictionary
    // https://developer.apple.com/documentation/foundation/httpurlresponse/1417930-allheaderfields
    static let etag = "Etag"

    static let cacheControl = "Cache-Control"
    static let retryAfter = "Retry-After"
}
