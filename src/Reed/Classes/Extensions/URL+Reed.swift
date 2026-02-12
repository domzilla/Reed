//
//  URL+Reed.swift
//  Reed
//
//  Created by Stuart Breckenridge on 03/05/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

private enum URLConstants {
    static let schemeHTTP = "http"
    static let schemeHTTPS = "https"
    static let prefixHTTP = "http://"
    static let prefixHTTPS = "https://"
}

extension URL {
    // MARK: - Email

    /// Percent encoded `mailto` URL for use with `canOpenUrl`. If the URL doesn't contain the `mailto` scheme, this is
    /// `nil`.
    var percentEncodedEmailAddress: URL? {
        guard scheme == "mailto" else {
            return nil
        }
        guard let urlString = absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: urlString)
    }

    /// Percent-encode spaces in links that may contain spaces but are otherwise already percent-encoded.
    ///
    /// For performance reasons, try this only if initial URL init fails.
    static func encodeSpacesIfNeeded(_ link: String?) -> URL? {
        guard let link, !link.isEmpty else {
            return nil
        }
        return URL(string: link.replacingOccurrences(of: " ", with: "%20"))
    }

    // MARK: - HTTP

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

    // MARK: - Query Items

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

    // MARK: - Browser

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
        // Returns self if it doesn't have the given prefix.

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
