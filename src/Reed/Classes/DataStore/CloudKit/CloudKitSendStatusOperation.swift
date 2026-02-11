//
//  CloudKitSendStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import RSWeb

final class CloudKitSendStatusOperation: MainThreadOperation, @unchecked Sendable {
    private let blockSize = 150
    private weak var dataStore: DataStore?
    private weak var articlesZone: CloudKitArticlesZone?
    private weak var refreshProgress: DownloadProgress?
    private let localProgress = DownloadProgress(numberOfTasks: 0)
    private var showProgress: Bool
    private var syncDatabase: SyncDatabase

    init(
        dataStore: DataStore,
        articlesZone: CloudKitArticlesZone,
        refreshProgress: DownloadProgress,
        showProgress: Bool,
        database: SyncDatabase
    ) {
        self.dataStore = dataStore
        self.articlesZone = articlesZone
        self.refreshProgress = refreshProgress
        self.showProgress = showProgress
        self.syncDatabase = database
        super.init(name: "CloudKitSendStatusOperation")

        if showProgress {
            refreshProgress.addChild(self.localProgress)
        }
    }

    @MainActor
    override func run() {
        DZLog("iCloud: Sending article statuses")

        Task { @MainActor in
            defer {
                localProgress.completeAll()
                didComplete()
            }

            do {
                if self.showProgress {
                    self.localProgress.addTask()
                }

                await selectForProcessing()
                DZLog("iCloud: Finished sending article statuses")
            } catch {
                DZLog("iCloud: Send status error: \(error.localizedDescription)")
            }
        }
    }
}

@MainActor
extension CloudKitSendStatusOperation {
    private func selectForProcessing() async {
        do {
            guard
                let syncStatuses = try await syncDatabase.selectForProcessing(limit: blockSize),
                !syncStatuses.isEmpty else
            {
                return
            }

            let stopProcessing = await processStatuses(Array(syncStatuses))
            if stopProcessing {
                return
            }

            await self.selectForProcessing()
        } catch {
            DZLog("iCloud: Send status error: \(error.localizedDescription)")
        }
    }

    /// Returns true if processing should stop.
    private func processStatuses(_ syncStatuses: [SyncStatus]) async -> Bool {
        guard let dataStore, let articlesZone else {
            return true
        }

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

        // If this happens, we have somehow gotten into a state where we have new status records
        // but the articles didn't come back in the fetch. We need to clean up those sync records
        // and stop processing.
        if statusUpdates.isEmpty {
            try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDs))
            return true
        } else {
            do {
                try await articlesZone.modifyArticles(statusUpdates)
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

    private func processSyncError(_ dataStore: DataStore, _ error: Error) {
        if case CloudKitZoneError.userDeletedZone = error {
            dataStore.removeFeedsFromTreeAtTopLevel(dataStore.topLevelFeeds)
            for folder in dataStore.folders ?? Set<Folder>() {
                dataStore.removeFolderFromTree(folder)
            }
        }
    }
}
