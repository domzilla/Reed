//
//  UnreadFeed.swift
//  Reed
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// This just shows the global unread count, which appDelegate already has. Easy.

@MainActor
final class UnreadFeed: PseudoFeed {
    var dataStore: DataStore?

    var defaultReadFilterType: ReadFilterType {
        .alwaysRead
    }

    var sidebarItemID: SidebarItemIdentifier? {
        SidebarItemIdentifier.smartFeed(String(describing: UnreadFeed.self))
    }

    let nameForDisplay = NSLocalizedString("All Unread", comment: "All Unread pseudo-feed title")
    let fetchType = FetchType.unread(nil)

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    var smallIcon: IconImage? {
        Assets.Images.unreadFeed
    }

    init() {
        self.unreadCount = appDelegate.unreadCount
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: appDelegate
        )
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        assert(note.object is AppDelegate)
        self.unreadCount = appDelegate.unreadCount
    }
}

@MainActor
extension UnreadFeed: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        try self.fetchUnreadArticles()
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await self.fetchUnreadArticlesAsync()
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try DataStore.shared.fetchArticles(self.fetchType)
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        try await DataStore.shared.fetchArticlesAsync(self.fetchType)
    }
}
