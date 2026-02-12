//
//  SyncStatus.swift
//  Reed
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase

struct SyncDatabaseKey: Sendable {
    static let articleID = "articleID"
    static let key = "key"
    static let flag = "flag"
    static let selected = "selected"
}

public struct SyncStatus: Sendable {
    public enum Key: String, Sendable {
        case read
        case starred
        case deleted
        case new

        public init(_ articleStatusKey: ArticleStatus.Key) {
            switch articleStatusKey {
            case .read:
                self = Self.read
            case .starred:
                self = Self.starred
            }
        }
    }

    public let articleID: String
    public let key: SyncStatus.Key
    public let flag: Bool
    public let selected: Bool

    public init(articleID: String, key: SyncStatus.Key, flag: Bool, selected: Bool = false) {
        self.articleID = articleID
        self.key = key
        self.flag = flag
        self.selected = selected
    }

    public nonisolated func databaseDictionary() -> DatabaseDictionary {
        [
            SyncDatabaseKey.articleID: self.articleID,
            SyncDatabaseKey.key: self.key.rawValue,
            SyncDatabaseKey.flag: self.flag,
            SyncDatabaseKey.selected: self.selected,
        ]
    }
}

// MARK: - Hashable

extension SyncStatus: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.articleID)
        hasher.combine(self.key)
    }

    public nonisolated static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        lhs.articleID == rhs.articleID && lhs.key == rhs.key
    }
}
