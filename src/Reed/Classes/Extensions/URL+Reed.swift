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
}
