//
//  SpecialCases.swift
//  Web
//
//  Created by Brent Simmons on 12/12/24.
//

import Foundation

nonisolated let localeForLowercasing = Locale(identifier: "en_US")

nonisolated enum SpecialCase {
    static let rachelByTheBayHostName = "rachelbythebay.com"
    static let openRSSOrgHostName = "openrss.org"

    static func urlStringContainSpecialCase(_ urlString: String, _ specialCases: [String]) -> Bool {
        let lowerURLString = urlString.lowercased(with: localeForLowercasing)
        for specialCase in specialCases {
            if lowerURLString.contains(specialCase) {
                return true
            }
        }
        return false
    }
}

nonisolated extension URL {
    var isOpenRSSOrgURL: Bool {
        guard let host = host() else {
            return false
        }
        return SpecialCase.urlStringContainSpecialCase(host, [SpecialCase.openRSSOrgHostName])
    }

    var isRachelByTheBayURL: Bool {
        guard let host = host() else {
            return false
        }
        return SpecialCase.urlStringContainSpecialCase(host, [SpecialCase.rachelByTheBayHostName])
    }
}

nonisolated extension Set<URL> {
    func byRemovingOpenRSSOrgURLs() -> Set<URL> {
        filter { !$0.isOpenRSSOrgURL }
    }

    func openRSSOrgURLs() -> Set<URL> {
        filter(\.isOpenRSSOrgURL)
    }

    func byRemovingAllButOneRandomOpenRSSOrgURL() -> Set<URL> {
        if self.isEmpty || self.count == 1 {
            return self
        }

        let openRSSOrgURLs = openRSSOrgURLs()
        if openRSSOrgURLs.isEmpty || openRSSOrgURLs.count == 1 {
            return self
        }

        let randomIndex = Int.random(in: 0..<openRSSOrgURLs.count)
        let singleOpenRSSOrgURLToRead = Array(openRSSOrgURLs)[randomIndex]

        var urls = self.byRemovingOpenRSSOrgURLs()
        urls.insert(singleOpenRSSOrgURLToRead)

        return urls
    }
}

nonisolated extension URLRequest {
    mutating func addSpecialCaseUserAgentIfNeeded() {
        guard let url else {
            return
        }

        if url.isOpenRSSOrgURL || url.isRachelByTheBayURL {
            setValue(UserAgent.extendedUserAgent, forHTTPHeaderField: HTTPRequestHeader.userAgent)
        }
    }
}

nonisolated extension UserAgent {
    static let extendedUserAgent = {
        let platform = "iOS"
        let version = stringFromInfoPlist("CFBundleShortVersionString") ?? "Unknown"
        let build = stringFromInfoPlist("CFBundleVersion") ?? "Unknown"

        let template = Bundle.main.object(forInfoDictionaryKey: "UserAgentExtended") as? String

        var userAgent = template!.replacingOccurrences(of: "[platform]", with: platform)
        userAgent = userAgent.replacingOccurrences(of: "[version]", with: version)
        userAgent = userAgent.replacingOccurrences(of: "[build]", with: build)

        return userAgent
    }()

    private static func stringFromInfoPlist(_ key: String) -> String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            assertionFailure("Expected to get \(key) from infoDictionary.")
            return nil
        }
        return s
    }
}
