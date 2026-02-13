//
//  CacheControlInfo.swift
//  Web
//
//  Created by Brent Simmons on 11/30/24.
//

import Foundation

/// Basic Cache-Control handling — just the part we need,
/// which is to know when we got the response (dateCreated)
/// and when we can ask again (canResume).
nonisolated struct CacheControlInfo: Codable, Equatable {
    let dateCreated: Date
    let maxAge: TimeInterval

    var resumeDate: Date {
        self.dateCreated + self.maxAge
    }

    var canResume: Bool {
        Date() >= self.resumeDate
    }

    init?(urlResponse: HTTPURLResponse) {
        guard let cacheControlValue = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.cacheControl) else {
            return nil
        }
        self.init(value: cacheControlValue)
    }

    /// Returns nil if there’s no max-age or it’s < 1.
    init?(value: String) {
        guard let maxAge = Self.parseMaxAge(value) else {
            return nil
        }

        let d = Date()
        self.dateCreated = d
        self.maxAge = maxAge
    }
}

nonisolated extension CacheControlInfo {
    fileprivate static let maxAgePrefix = "max-age="
    fileprivate static let maxAgePrefixCount = maxAgePrefix.count

    fileprivate static func parseMaxAge(_ s: String) -> TimeInterval? {
        let components = s.components(separatedBy: ",")
        let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespaces) }

        for component in trimmedComponents {
            if component.hasPrefix(Self.maxAgePrefix) {
                let maxAgeStringValue = component.dropFirst(self.maxAgePrefixCount)
                if let timeInterval = TimeInterval(maxAgeStringValue), timeInterval > 0 {
                    return timeInterval
                }
            }
        }

        return nil
    }
}
