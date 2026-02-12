//
//  HTMLMetadataCache.swift
//
//
//  Created by Brent Simmons on 10/13/24.
//

import Foundation

extension Notification.Name {
    // Sent when HTMLMetadata is cached. Posted on any thread.
    nonisolated static let htmlMetadataAvailable = Notification.Name("htmlMetadataAvailable")
}

final nonisolated class HTMLMetadataCache: Sendable {
    static let shared = HTMLMetadataCache()

    // Sent along with .htmlMetadataAvailable notification
    enum UserInfoKey {
        static let htmlMetadata = "htmlMetadata"
        static let url = "url" // String value
    }

    private struct HTMLMetadataCacheRecord: CacheRecord {
        let metadata: RDHTMLMetadata
        let dateCreated = Date()
    }

    private let cache = Cache<HTMLMetadataCacheRecord>(
        timeToLive: TimeInterval(hours: 21),
        timeBetweenCleanups: TimeInterval(hours: 10)
    )

    subscript(_ url: String) -> RDHTMLMetadata? {
        get {
            self.cache[url]?.metadata
        }
        set {
            guard let htmlMetadata = newValue else {
                return
            }
            let cacheRecord = HTMLMetadataCacheRecord(metadata: htmlMetadata)
            self.cache[url] = cacheRecord
            NotificationCenter.default.post(
                name: .htmlMetadataAvailable,
                object: self,
                userInfo: [UserInfoKey.htmlMetadata: htmlMetadata, UserInfoKey.url: url]
            )
        }
    }
}
