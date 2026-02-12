//
//  HTTPResponseCode.swift
//  Web
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum HTTPResponseCode {
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html

    static let notModified = 304

    static let redirectPermanent = 301
    static let redirectTemporary = 302
    static let redirectVeryTemporary = 307
    static let redirectPermanentPreservingMethod = 308

    static let badRequest = 400
    static let notAcceptable = 406
    static let tooManyRequests = 429
}
