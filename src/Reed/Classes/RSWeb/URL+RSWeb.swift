//
//  URL+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

private enum URLConstants {
    static let schemeHTTP = "http"
    static let schemeHTTPS = "https"
    static let prefixHTTP = "http://"
    static let prefixHTTPS = "https://"
}

extension URL {
    func isHTTPSURL() -> Bool {
        self.scheme?.lowercased(with: localeForLowercasing) == URLConstants.schemeHTTPS
    }

    func isHTTPURL() -> Bool {
        self.scheme?.lowercased(with: localeForLowercasing) == URLConstants.schemeHTTP
    }

    func isHTTPOrHTTPSURL() -> Bool {
        self.isHTTPSURL() || self.isHTTPURL()
    }

    func absoluteStringWithHTTPOrHTTPSPrefixRemoved() -> String? {
        // Case-inensitive. Turns http://example.com/foo into example.com/foo

        if self.isHTTPSURL() {
            return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTPS)
        } else if self.isHTTPURL() {
            return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTP)
        }

        return nil
    }

    func appendingQueryItem(_ queryItem: URLQueryItem) -> URL? {
        self.appendingQueryItems([queryItem])
    }

    func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var newQueryItems = components.queryItems ?? []
        newQueryItems.append(contentsOf: queryItems)
        components.queryItems = newQueryItems

        return components.url
    }

    func preparedForOpeningInBrowser() -> URL? {
        var urlString = absoluteString.replacingOccurrences(of: " ", with: "%20")
        urlString = urlString.replacingOccurrences(of: "^", with: "%5E")
        urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
        urlString = urlString.replacingOccurrences(of: "&#38;", with: "&")

        return URL(string: urlString)
    }
}

extension String {
    fileprivate func stringByRemovingCaseInsensitivePrefix(_ prefix: String) -> String {
        // Returns self if it doesn’t have the given prefix.

        let lowerPrefix = prefix.lowercased()
        let lowerSelf = self.lowercased()

        if lowerSelf == lowerPrefix {
            return ""
        }
        if !lowerSelf.hasPrefix(lowerPrefix) {
            return self
        }

        let index = self.index(self.startIndex, offsetBy: prefix.count)
        return String(self[..<index])
    }
}
