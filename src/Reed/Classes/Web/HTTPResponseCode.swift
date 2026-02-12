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
    // Not an enum because the main interest is the actual values.

    static let responseContinue = 100 // "continue" is a language keyword, hence the weird name
    static let switchingProtocols = 101

    static let OK = 200
    static let created = 201
    static let accepted = 202
    static let nonAuthoritativeInformation = 203
    static let noContent = 204
    static let resetContent = 205
    static let partialContent = 206

    static let redirectMultipleChoices = 300
    static let redirectPermanent = 301
    static let redirectTemporary = 302
    static let redirectSeeOther = 303
    static let notModified = 304
    static let useProxy = 305
    static let unused = 306
    static let redirectVeryTemporary = 307
    static let redirectPermanentPreservingMethod = 308

    static let badRequest = 400
    static let unauthorized = 401
    static let paymentRequired = 402
    static let forbidden = 403
    static let notFound = 404
    static let methodNotAllowed = 405
    static let notAcceptable = 406
    static let proxyAuthenticationRequired = 407
    static let requestTimeout = 408
    static let conflict = 409
    static let gone = 410
    static let lengthRequired = 411
    static let preconditionFailed = 412
    static let entityTooLarge = 413
    static let URITooLong = 414
    static let unsupportedMediaType = 415
    static let requestedRangeNotSatisfiable = 416
    static let expectationFailed = 417
    static let imATeapot = 418
    static let misdirectedRequest = 421
    static let unprocessableContentWebDAV = 422
    static let lockedWebDAV = 423
    static let failedDependencyWebDAV = 424
    static let tooEarly = 425
    static let upgradeRequired = 426
    static let preconditionRequired = 428
    static let tooManyRequests = 429
    static let requestHeaderFieldsTooLarge = 431
    static let unavailableForLegalReasons = 451

    static let internalServerError = 500
    static let notImplemented = 501
    static let badGateway = 502
    static let serviceUnavailable = 503
    static let gatewayTimeout = 504
    static let HTTPVersionNotSupported = 505
}
