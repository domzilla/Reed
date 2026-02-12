//
//  HTTPConditionalGetInfo.swift
//  Web
//
//  Created by Brent Simmons on 4/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated struct HTTPConditionalGetInfo: Codable, Equatable {
    let lastModified: String?
    let etag: String?

    init?(lastModified: String?, etag: String?) {
        if lastModified == nil, etag == nil {
            return nil
        }
        self.lastModified = lastModified
        self.etag = etag
    }

    init?(urlResponse: HTTPURLResponse) {
        let lastModified = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.lastModified)
        let etag = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.etag)
        self.init(lastModified: lastModified, etag: etag)
    }

    init?(headers: [AnyHashable: Any]) {
        let lastModified = headers[HTTPResponseHeader.lastModified] as? String
        let etag = headers[HTTPResponseHeader.etag] as? String
        self.init(lastModified: lastModified, etag: etag)
    }

    func addRequestHeadersToURLRequest(_ urlRequest: inout URLRequest) {
        // Bug seen in the wild: lastModified with last possible 32-bit date, which is in 2038. Ignore those.
        // TODO: drop this check in late 2037.
        if let lastModified, !lastModified.contains("2038") {
            urlRequest.addValue(lastModified, forHTTPHeaderField: HTTPRequestHeader.ifModifiedSince)
        }
        if let etag {
            urlRequest.addValue(etag, forHTTPHeaderField: HTTPRequestHeader.ifNoneMatch)
        }
    }
}
