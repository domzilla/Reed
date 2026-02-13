//
//  CloudKitSyncProvider+ArticleStatus.swift
//  Reed
//
//  Extracted from CloudKitSyncProvider.swift
//

import DZFoundation
import Foundation

// MARK: - Article Status

extension CloudKitSyncProvider {
    func markArticles(
        for dataStore: DataStore,
        articles: Set<Article>,
        statusKey: ArticleStatus.Key,
        flag: Bool
    ) async throws {
        let articles = try await dataStore.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
        let syncStatuses = Set(articles.map { article in
            SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
        })

        try await self.syncDatabase.insertStatuses(syncStatuses)
        if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
            try await self.sendArticleStatus(for: dataStore)
        }
    }

    func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {
        guard let articles, !articles.isEmpty else {
            return
        }
        let syncStatuses = Set(articles.map { article in
            SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
        })
        try? await self.syncDatabase.insertStatuses(syncStatuses)
    }

    func sendArticleStatus(dataStore: DataStore, showProgress: Bool) async throws {
        DZLog("iCloud: Sending article statuses")
        let blockSize = 150
        let localProgress = DownloadProgress(numberOfTasks: 0)

        if showProgress {
            self.refreshProgress.addChild(localProgress)
        }

        defer {
            localProgress.completeAll()
        }

        if showProgress {
            localProgress.addTask()
        }

        try await self.sendStatusBatch(
            dataStore: dataStore,
            blockSize: blockSize
        )
        DZLog("iCloud: Finished sending article statuses")
    }

    // MARK: - Private

    /// Recursively processes sync status batches until none remain.
    private func sendStatusBatch(
        dataStore: DataStore,
        blockSize: Int
    ) async throws {
        guard
            let syncStatuses = try await self.syncDatabase.selectForProcessing(limit: blockSize),
            !syncStatuses.isEmpty else
        {
            return
        }

        let stopProcessing = try await self.processSendStatuses(
            Array(syncStatuses),
            dataStore: dataStore
        )
        if stopProcessing {
            return
        }

        try await self.sendStatusBatch(
            dataStore: dataStore,
            blockSize: blockSize
        )
    }

    /// Returns true if processing should stop.
    private func processSendStatuses(
        _ syncStatuses: [SyncStatus],
        dataStore: DataStore
    ) async throws
        -> Bool
    {
        let articleIDs = syncStatuses.map(\.articleID)
        let articles: Set<Article>

        do {
            articles = try await dataStore.fetchArticlesAsync(.articleIDs(Set(articleIDs)))
        } catch {
            try? await self.syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map(\.articleID)))
            DZLog("iCloud: Send article status fetch articles error: \(error.localizedDescription)")
            return true
        }

        let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
        let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
            result[article.articleID] = article
        }
        let statusUpdates = syncStatusesDict.compactMap { key, value in
            CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key])
        }

        if statusUpdates.isEmpty {
            try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDs))
            return true
        } else {
            do {
                try await self.articlesZone.modifyArticles(statusUpdates)
                try? await self.syncDatabase.deleteSelectedForProcessing(Set(statusUpdates.map(\.articleID)))
                return false
            } catch {
                try? await self.syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map(\.articleID)))
                self.processSyncError(dataStore, error)
                DZLog("iCloud: Send article status modify articles error: \(error.localizedDescription)")
                return true
            }
        }
    }

    // MARK: - Article Change Storage

    func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {
        // New records with a read status aren't really new, they just didn't have the read article stored
        await withTaskGroup(of: Void.self) { group in
            if let new {
                let filteredNew = new.filter { $0.status.read == false }
                group.addTask {
                    await self.insertSyncStatuses(articles: filteredNew, statusKey: .new, flag: true)
                }
            }

            group.addTask {
                await self.insertSyncStatuses(articles: updated, statusKey: .new, flag: false)
            }

            group.addTask {
                await self.insertSyncStatuses(articles: deleted, statusKey: .deleted, flag: true)
            }
        }
    }

    func processSyncError(_ dataStore: DataStore, _ error: Error) {
        if case CloudKitZoneError.userDeletedZone = error {
            dataStore.removeFeedsFromTreeAtTopLevel(dataStore.topLevelFeeds)
            for folder in dataStore.folders ?? Set<Folder>() {
                dataStore.removeFolderFromTree(folder)
            }
        }
    }
}
