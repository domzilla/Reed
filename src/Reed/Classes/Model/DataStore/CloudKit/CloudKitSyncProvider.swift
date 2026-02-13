//
//  CloudKitSyncProvider.swift
//  Account
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import DZFoundation
import Foundation
import SystemConfiguration

enum CloudKitSyncProviderError: LocalizedError, Sendable {
    case invalidParameter
    case unknown

    var errorDescription: String? {
        NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
    }
}

@MainActor
final class CloudKitSyncProvider: SyncProvider {
    let syncDatabase: SyncDatabase

    private let container: CKContainer = AppConstants.cloudKitContainer

    let feedsZone: CloudKitFeedsZone
    let articlesZone: CloudKitArticlesZone

    private let refresher: FeedRefresher

    weak var dataStore: DataStore?

    let isOPMLImportInProgress = false

    let server: String? = nil
    var dataStoreMetadata: DataStoreMetadata?

    /// refreshProgress is combined sync progress and feed download progress.
    let refreshProgress = DownloadProgress(numberOfTasks: 0)
    let syncProgress = DownloadProgress(numberOfTasks: 0)

    /// Counter for generating local external IDs when iCloud is unavailable.
    private var localIDCounter = 0

    init(dataFolder: String) {
        self.feedsZone = CloudKitFeedsZone(container: self.container)
        self.articlesZone = CloudKitArticlesZone(container: self.container)

        let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
        self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

        self.refresher = FeedRefresher()
        self.refresher.delegate = self

        // Listen for iCloud account status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.iCloudAccountStatusDidChange(_:)),
            name: .iCloudAccountStatusDidChange,
            object: nil
        )
    }

    // MARK: - iCloud Account Status

    @objc
    private func iCloudAccountStatusDidChange(_: Notification) {
        guard iCloudAccountMonitor.shared.isAvailable, let dataStore else {
            return
        }

        Task {
            await processPendingOperations(for: dataStore)
        }
    }

    /// Generate a local external ID for use when iCloud is unavailable.
    func generateLocalExternalID() -> String {
        self.localIDCounter += 1
        return "local-\(UUID().uuidString)"
    }

    // MARK: - Refresh / Sync Orchestration

    func receiveRemoteNotification(for _: DataStore, userInfo: [AnyHashable: Any]) async {
        DZLog("iCloud: Processing remote notification")
        await self.feedsZone.receiveRemoteNotification(userInfo: userInfo)
        await self.articlesZone.receiveRemoteNotification(userInfo: userInfo)
        DZLog("iCloud: Finished processing remote notification")
    }

    func refreshAll(for dataStore: DataStore) async throws {
        guard self.syncProgress.isComplete else {
            DZLog(
                "iCloud: refreshAll BLOCKED — syncProgress not complete (tasks: \(self.syncProgress.progressInfo.numberOfTasks), completed: \(self.syncProgress.progressInfo.numberCompleted), remaining: \(self.syncProgress.progressInfo.numberRemaining))"
            )
            return
        }

        guard NetworkMonitor.shared.isConnected else {
            DZLog("iCloud: refreshAll skipped — not connected")
            return
        }

        await standardRefreshAll(for: dataStore)
    }

    func syncArticleStatus(for dataStore: DataStore) async throws {
        try await self.sendArticleStatus(for: dataStore)
        try await self.refreshArticleStatus(for: dataStore)
    }

    func sendArticleStatus(for dataStore: DataStore) async throws {
        try await self.sendArticleStatus(dataStore: dataStore, showProgress: false)
    }

    func refreshArticleStatus(for _: DataStore) async throws {
        DZLog("iCloud: Refreshing article statuses")
        do {
            try await self.articlesZone.refreshArticles()
            DZLog("iCloud: Finished refreshing article statuses")
        } catch {
            DZLog("iCloud: Receive status error: \(error.localizedDescription)")
            throw error
        }
    }

    func importOPML(for dataStore: DataStore, opmlFile: URL) async throws {
        guard self.syncProgress.isComplete else {
            return
        }

        let opmlData = try Data(contentsOf: opmlFile)
        let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
        let opmlDocument = try RDOPMLParser.parseOPML(with: parserData)

        // TODO: throw appropriate error if OPML file is empty.
        guard let opmlItems = opmlDocument.children, let rootExternalID = dataStore.externalID else {
            return
        }
        let normalizedItems = OPMLNormalizer.normalize(opmlItems)

        self.syncProgress.addTask()
        defer { syncProgress.completeTask() }

        do {
            try await self.feedsZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
            await standardRefreshAll(for: dataStore)
        } catch {
            throw error
        }
    }

    // MARK: - Lifecycle

    func dataStoreDidInitialize(_ dataStore: DataStore) {
        self.dataStore = dataStore

        self.feedsZone.delegate = CloudKitFeedsZoneDelegate(dataStore: dataStore, articlesZone: self.articlesZone)
        self.articlesZone.delegate = CloudKitArticlesZoneDelegate(
            dataStore: dataStore,
            database: self.syncDatabase,
            articlesZone: self.articlesZone
        )

        self.syncDatabase.resetAllSelectedForProcessing()
        self.syncDatabase.resetAllPendingOperationsSelectedForProcessing()

        // Check to see if this is a new dataStore and initialize anything we need
        if dataStore.externalID == nil {
            // Always start with a local ID - CloudKit setup will happen via notification
            // when iCloud account status is determined
            dataStore.externalID = self.generateLocalExternalID()
            DZLog("iCloud: Using local dataStore ID (will upgrade when iCloud confirmed available)")
        }
    }

    func dataStoreWillBeDeleted(_: DataStore) {
        self.feedsZone.resetChangeToken()
        self.articlesZone.resetChangeToken()
    }

    // MARK: - Suspend and Resume (for iOS)

    func suspendNetwork() {
        self.refresher.suspend()
    }

    func suspendDatabase() {
        self.syncDatabase.suspend()
    }

    func resume() {
        self.refresher.resume()
        self.syncDatabase.resume()
    }
}

// MARK: - Private Orchestration

extension CloudKitSyncProvider {
    func initialRefreshAll(for dataStore: DataStore) async {
        await self.performRefreshAll(for: dataStore, sendArticleStatus: false)
    }

    private func standardRefreshAll(for dataStore: DataStore) async {
        await self.performRefreshAll(for: dataStore, sendArticleStatus: true)
    }

    private func performRefreshAll(for dataStore: DataStore, sendArticleStatus: Bool) async {
        self.syncProgress.addTasks(3)

        // Try CloudKit sync if iCloud is available
        if iCloudAccountMonitor.shared.isAvailable {
            do {
                try await self.feedsZone.fetchChangesInZone()
                self.syncProgress.completeTask()

                try await self.refreshArticleStatus(for: dataStore)
                self.syncProgress.completeTask()
            } catch {
                // Handle CloudKit errors gracefully — never block feed refresh
                self.syncProgress.completeTask()
                self.syncProgress.completeTask()

                if iCloudAccountMonitor.isRecoverableError(error) {
                    DZLog("iCloud: Sync skipped due to recoverable error: \(error.localizedDescription)")
                } else {
                    DZLog("iCloud: Non-recoverable sync error: \(error)")
                    self.processSyncError(dataStore, error)
                }
            }
        } else {
            // iCloud not available - skip CloudKit sync silently
            self.syncProgress.completeTask()
            self.syncProgress.completeTask()
            DZLog("iCloud: Skipping sync (iCloud not available)")
        }

        // Always refresh local feeds regardless of CloudKit sync result
        let feeds = dataStore.flattenedFeeds()
        await self.refresher.refreshFeeds(feeds)

        if sendArticleStatus, iCloudAccountMonitor.shared.isAvailable {
            do {
                try await self.sendArticleStatus(dataStore: dataStore, showProgress: true)
            } catch {
                if !iCloudAccountMonitor.isRecoverableError(error) {
                    DZLog("iCloud: Send article status failed: \(error.localizedDescription)")
                }
            }
        }

        self.syncProgress.completeTask()
        dataStore.metadata.lastArticleFetchEndTime = Date()
    }
}

// MARK: - FeedRefresherDelegate

extension CloudKitSyncProvider: FeedRefresherDelegate {
    func feedRefresher(_: FeedRefresher, articleChanges: ArticleChanges) {
        Task {
            await self.storeArticleChanges(
                new: articleChanges.new,
                updated: articleChanges.updated,
                deleted: articleChanges.deleted
            )
        }
    }
}
