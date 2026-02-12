//
//  SmartFeed.swift
//  Reed
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
final class SmartFeed: PseudoFeed {
    var dataStore: DataStore?

    var defaultReadFilterType: ReadFilterType {
        .none
    }

    var sidebarItemID: SidebarItemIdentifier? {
        self.delegate.sidebarItemID
    }

    var nameForDisplay: String {
        self.delegate.nameForDisplay
    }

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    var smallIcon: IconImage? {
        self.delegate.smallIcon
    }

    private let delegate: SmartFeedDelegate
    private var unreadCounts = [String: Int]()

    init(delegate: SmartFeedDelegate) {
        self.delegate = delegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        queueFetchUnreadCounts() // Fetch unread count at startup
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if note.object is AppDelegate {
            queueFetchUnreadCounts()
        }
    }

    @objc
    func fetchUnreadCounts() {
        let activeDataStores = DataStoreManager.shared.activeDataStores

        // Remove any data stores that are no longer active or have been deleted
        let activeDataStoreIDs = activeDataStores.map(\.dataStoreID)
        for dataStoreID in self.unreadCounts.keys {
            if !activeDataStoreIDs.contains(dataStoreID) {
                self.unreadCounts.removeValue(forKey: dataStoreID)
            }
        }

        if activeDataStores.isEmpty {
            updateUnreadCount()
        } else {
            for dataStore in activeDataStores {
                fetchUnreadCount(dataStore: dataStore)
            }
        }
    }
}

extension SmartFeed: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        try self.delegate.fetchArticles()
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await self.delegate.fetchArticlesAsync()
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.delegate.fetchUnreadArticles()
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        try await self.delegate.fetchUnreadArticlesAsync()
    }
}

extension SmartFeed {
    private func queueFetchUnreadCounts() {
        CoalescingQueue.standard.add(self, #selector(self.fetchUnreadCounts))
    }

    private func fetchUnreadCount(dataStore: DataStore) {
        Task { @MainActor in
            guard let unreadCount = try? await delegate.fetchUnreadCount(dataStore: dataStore) else {
                return
            }
            self.unreadCounts[dataStore.dataStoreID] = unreadCount
            self.updateUnreadCount()
        }
    }

    private func updateUnreadCount() {
        var updatedUnreadCount = 0
        for dataStore in DataStoreManager.shared.activeDataStores {
            if let oneUnreadCount = unreadCounts[dataStore.dataStoreID] {
                updatedUnreadCount += oneUnreadCount
            }
        }

        self.unreadCount = updatedUnreadCount
    }
}
