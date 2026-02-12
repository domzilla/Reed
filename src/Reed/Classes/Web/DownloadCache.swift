//
//  DownloadCache.swift
//  Web
//
//  Created by Brent Simmons on 10/16/25.
//

import Foundation

struct DownloadCacheRecord: CacheRecord, Sendable {
    let dateCreated = Date()
    let data: Data?
    let response: URLResponse?

    init(data: Data?, response: URLResponse?) {
        self.data = data
        self.response = response
    }
}

final nonisolated class DownloadCache: Sendable {
    static let shared = DownloadCache()

    private let cache = Cache<DownloadCacheRecord>(timeToLive: 60 * 13, timeBetweenCleanups: 60 * 2)

    subscript(_ key: String) -> DownloadCacheRecord? {
        get {
            self.cache[key]
        }
        set {
            self.cache[key] = newValue
        }
    }

    func add(_ urlString: String, data: Data?, response: URLResponse?) {
        let cacheRecord = DownloadCacheRecord(data: data, response: response)
        self.cache[urlString] = cacheRecord
    }
}
