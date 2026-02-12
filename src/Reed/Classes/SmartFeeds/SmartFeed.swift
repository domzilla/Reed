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
        SidebarItemIdentifier.smartFeed(self.identifier)
    }

    let nameForDisplay: String
    let fetchType: FetchType
    var smallIcon: IconImage?

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    private let identifier: String
    private let unreadCountFetcher: (@MainActor (DataStore) async throws -> Int?)?
    private var unreadCounts = [String: Int]()

    init(
        identifier: String,
        nameForDisplay: String,
        fetchType: FetchType,
        smallIcon: IconImage?,
        unreadCountFetcher: (@MainActor (DataStore) async throws -> Int?)? = nil
    ) {
        self.identifier = identifier
        self.nameForDisplay = nameForDisplay
        self.fetchType = fetchType
        self.smallIcon = smallIcon
        self.unreadCountFetcher = unreadCountFetcher

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        queueFetchUnreadCounts()
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if note.object is AppDelegate {
            queueFetchUnreadCounts()
        }
    }

    @objc
    func fetchUnreadCounts() {
        let activeDataStores = DataStore.shared.activeDataStores

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

// MARK: - ArticleFetcher

extension SmartFeed: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        try DataStore.shared.fetchArticles(self.fetchType)
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await DataStore.shared.fetchArticlesAsync(self.fetchType)
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.fetchArticles().unreadArticles()
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        let articles = try await fetchArticlesAsync()
        return articles.unreadArticles()
    }
}

// MARK: - Private

extension SmartFeed {
    private func queueFetchUnreadCounts() {
        CoalescingQueue.standard.add(self, #selector(self.fetchUnreadCounts))
    }

    private func fetchUnreadCount(dataStore: DataStore) {
        Task { @MainActor in
            guard let unreadCount = try? await self.unreadCountFetcher?(dataStore) else {
                return
            }
            self.unreadCounts[dataStore.dataStoreID] = unreadCount
            self.updateUnreadCount()
        }
    }

    private func updateUnreadCount() {
        var updatedUnreadCount = 0
        for dataStore in DataStore.shared.activeDataStores {
            if let oneUnreadCount = unreadCounts[dataStore.dataStoreID] {
                updatedUnreadCount += oneUnreadCount
            }
        }

        self.unreadCount = updatedUnreadCount
    }
}
