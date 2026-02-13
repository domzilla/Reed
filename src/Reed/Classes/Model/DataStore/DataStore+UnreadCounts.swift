//
//  DataStore+UnreadCounts.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import Foundation

// MARK: - Unread Counts

extension DataStore {
    func unreadCount(for feed: Feed) -> Int {
        self.unreadCounts[feed.feedID] ?? 0
    }

    func setUnreadCount(_ unreadCount: Int, for feed: Feed) {
        self.unreadCounts[feed.feedID] = unreadCount
    }

    func updateUnreadCounts(feeds: Set<Feed>) {
        _fetchUnreadCounts(feeds: feeds)
    }
}

// MARK: - Fetching Unread Counts (Private)

@MainActor
extension DataStore {
    /// Fetch unread counts for zero or more feeds.
    ///
    /// Uses the most efficient method based on how many feeds were passed in.
    private func _fetchUnreadCounts(for feeds: Set<Feed>) {
        if feeds.isEmpty {
            return
        }
        if feeds.count == 1, let feed = feeds.first {
            self._fetchUnreadCount(feed: feed)
        } else if feeds.count < 10 {
            self._fetchUnreadCounts(feeds: feeds)
        } else {
            self._fetchAllUnreadCounts()
        }
    }

    private func _fetchUnreadCount(feed: Feed) {
        Task { @MainActor in
            guard let unreadCount = try? await database.fetchUnreadCountAsync(feedID: feed.feedID) else {
                return
            }
            feed.unreadCount = unreadCount
        }
    }

    private func _fetchUnreadCounts(feeds: Set<Feed>) {
        Task { @MainActor in
            guard let unreadCountDictionary = try? await database.fetchUnreadCountsAsync(feedIDs: feeds.feedIDs()) else {
                return
            }
            self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: feeds)
        }
    }

    func _fetchAllUnreadCounts() {
        self.fetchingAllUnreadCounts = true

        Task { @MainActor in
            guard let unreadCountDictionary = try? await database.fetchAllUnreadCountsAsync() else {
                return
            }

            self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: self.flattenedFeeds())
            self.fetchingAllUnreadCounts = false
            self.updateUnreadCount()

            if !self.areUnreadCountsInitialized {
                self.areUnreadCountsInitialized = true
                self.postUnreadCountDidInitializeNotification()
            }
        }
    }

    private func processUnreadCounts(unreadCountDictionary: UnreadCountDictionary, feeds: Set<Feed>) {
        for feed in feeds {
            // When the unread count is zero, it won't appear in unreadCountDictionary.
            let unreadCount = unreadCountDictionary[feed.feedID] ?? 0
            feed.unreadCount = unreadCount
        }
    }

    func updateUnreadCount() {
        if self.fetchingAllUnreadCounts {
            return
        }
        var updatedUnreadCount = 0
        for feed in self.flattenedFeeds() {
            updatedUnreadCount += feed.unreadCount
        }
        self.unreadCount = updatedUnreadCount
    }
}
