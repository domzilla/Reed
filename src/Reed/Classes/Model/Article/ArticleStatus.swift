//
//  ArticleStatus.swift
//  Reed
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

final class ArticleStatus: Sendable {
    enum Key: String, Sendable {
        case read
        case starred
    }

    let articleID: String
    let dateArrived: Date

    private struct State: Sendable {
        var read: Bool
        var starred: Bool
    }

    private let state: Mutex<State>

    nonisolated var read: Bool {
        get {
            self.state.withLock { $0.read }
        }
        set {
            self.state.withLock { $0.read = newValue }
        }
    }

    nonisolated var starred: Bool {
        get {
            self.state.withLock { $0.starred }
        }
        set {
            self.state.withLock { $0.starred = newValue }
        }
    }

    init(articleID: String, read: Bool, starred: Bool, dateArrived: Date) {
        self.articleID = articleID
        self.state = Mutex(State(read: read, starred: starred))
        self.dateArrived = dateArrived
    }

    convenience init(articleID: String, read: Bool, dateArrived: Date) {
        self.init(articleID: articleID, read: read, starred: false, dateArrived: dateArrived)
    }

    nonisolated func boolStatus(forKey key: ArticleStatus.Key) -> Bool {
        switch key {
        case .read:
            self.read
        case .starred:
            self.starred
        }
    }

    nonisolated func setBoolStatus(_ status: Bool, forKey key: ArticleStatus.Key) {
        switch key {
        case .read:
            self.read = status
        case .starred:
            self.starred = status
        }
    }
}

// MARK: - Hashable

extension ArticleStatus: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.articleID)
    }

    nonisolated static func == (lhs: ArticleStatus, rhs: ArticleStatus) -> Bool {
        lhs.articleID == rhs.articleID && lhs.dateArrived == rhs.dateArrived && lhs.read == rhs.read && lhs
            .starred == rhs.starred
    }
}

extension Set<ArticleStatus> {
    func articleIDs() -> Set<String> {
        Set<String>(map(\.articleID))
    }
}

extension [ArticleStatus] {
    func articleIDs() -> [String] {
        map(\.articleID)
    }
}
