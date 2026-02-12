//
//  SyncStatus.swift
//  Reed
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

struct SyncDatabaseKey: Sendable {
    static let articleID = "articleID"
    static let key = "key"
    static let flag = "flag"
    static let selected = "selected"
}

struct SyncStatus: Sendable {
    enum Key: String, Sendable {
        case read
        case starred
        case deleted
        case new

        init(_ articleStatusKey: ArticleStatus.Key) {
            switch articleStatusKey {
            case .read:
                self = Self.read
            case .starred:
                self = Self.starred
            }
        }
    }

    let articleID: String
    let key: SyncStatus.Key
    let flag: Bool
    let selected: Bool

    init(articleID: String, key: SyncStatus.Key, flag: Bool, selected: Bool = false) {
        self.articleID = articleID
        self.key = key
        self.flag = flag
        self.selected = selected
    }

    nonisolated func databaseDictionary() -> DatabaseDictionary {
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
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.articleID)
        hasher.combine(self.key)
    }

    nonisolated static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        lhs.articleID == rhs.articleID && lhs.key == rhs.key
    }
}
