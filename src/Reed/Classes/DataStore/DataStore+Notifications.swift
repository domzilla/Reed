//
//  DataStore+Notifications.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import Foundation

// MARK: - Notifications

extension DataStore {
    @objc
    func downloadProgressDidChange(_ note: Notification) {
        guard let noteObject = note.object as? DownloadProgress, noteObject === refreshProgress else {
            return
        }

        self.refreshInProgress = !self.refreshProgress.isComplete
        NotificationCenter.default.post(name: .DataStoreRefreshProgressDidChange, object: self)
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if let feed = note.object as? Feed, feed.dataStore === self {
            updateUnreadCount()
        }
    }

    @objc
    func batchUpdateDidPerform(_: Notification) {
        self.flattenedFeedsNeedUpdate = true
        rebuildFeedDictionaries()
        updateUnreadCount()
    }

    @objc
    func childrenDidChange(_ note: Notification) {
        guard let object = note.object else {
            return
        }
        if let dataStore = object as? DataStore, dataStore === self {
            self.structureDidChange()
            updateUnreadCount()
        }
        if let folder = object as? Folder, folder.dataStore === self {
            self.structureDidChange()
        }
    }

    @objc
    func displayNameDidChange(_ note: Notification) {
        if let folder = note.object as? Folder, folder.dataStore === self {
            self.structureDidChange()
        }
    }
}

// MARK: - Status Change Notifications

@MainActor
extension DataStore {
    func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
        let feeds = Set(articles.compactMap(\.feed))
        let statuses = Set(articles.map(\.status))
        let articleIDs = Set(articles.map(\.articleID))

        // .UnreadCountDidChange notification will get sent to Folder and DataStore objects,
        // which will update their own unread counts.
        self.updateUnreadCounts(feeds: feeds)

        NotificationCenter.default.post(
            name: .StatusesDidChange,
            object: self,
            userInfo: [
                UserInfoKey.statuses: statuses,
                UserInfoKey.articles: articles,
                UserInfoKey.articleIDs: articleIDs,
                UserInfoKey.feeds: feeds,
            ]
        )
    }

    func noteStatusesForArticleIDsDidChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) {
        self._fetchAllUnreadCounts()
        NotificationCenter.default.post(
            name: .StatusesDidChange,
            object: self,
            userInfo: [
                UserInfoKey.articleIDs: articleIDs,
                UserInfoKey.statusKey: statusKey,
                UserInfoKey.statusFlag: flag,
            ]
        )
    }

    func noteStatusesForArticleIDsDidChange(_ articleIDs: Set<String>) {
        self._fetchAllUnreadCounts()
        NotificationCenter.default.post(
            name: .StatusesDidChange,
            object: self,
            userInfo: [UserInfoKey.articleIDs: articleIDs]
        )
    }

    func sendNotificationAbout(_ articleChanges: ArticleChanges) {
        var feeds = Set<Feed>()

        if let newArticles = articleChanges.new {
            feeds.formUnion(Set(newArticles.compactMap(\.feed)))
        }
        if let updatedArticles = articleChanges.updated {
            feeds.formUnion(Set(updatedArticles.compactMap(\.feed)))
        }

        var shouldSendNotification = false
        var shouldUpdateUnreadCounts = false
        var userInfo = [String: Any]()

        if let newArticles = articleChanges.new, !newArticles.isEmpty {
            shouldSendNotification = true
            shouldUpdateUnreadCounts = true
            userInfo[UserInfoKey.newArticles] = newArticles
        }

        if let updatedArticles = articleChanges.updated, !updatedArticles.isEmpty {
            shouldSendNotification = true
            userInfo[UserInfoKey.updatedArticles] = updatedArticles
        }

        if let deletedArticles = articleChanges.deleted, !deletedArticles.isEmpty {
            shouldUpdateUnreadCounts = true
        }

        if shouldUpdateUnreadCounts {
            self.updateUnreadCounts(feeds: feeds)
        }

        if shouldSendNotification {
            userInfo[UserInfoKey.feeds] = feeds
            let capturedSelf = self
            nonisolated(unsafe) let capturedUserInfo = userInfo
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .DataStoreDidDownloadArticles,
                    object: capturedSelf,
                    userInfo: capturedUserInfo
                )
            }
        }
    }
}
