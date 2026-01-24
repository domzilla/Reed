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
import RSCore
import RSParser
import RSWeb
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
    private let syncDatabase: SyncDatabase

    private let container: CKContainer = {
        let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
        return CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
    }()

    private let feedsZone: CloudKitFeedsZone
    private let articlesZone: CloudKitArticlesZone

    private let mainThreadOperationQueue = MainThreadOperationQueue()
    private let refresher: LocalAccountRefresher

    weak var dataStore: DataStore?

    let isOPMLImportInProgress = false

    let server: String? = nil
    var dataStoreMetadata: DataStoreMetadata?

    /// refreshProgress is combined sync progress and feed download progress.
    let refreshProgress = DownloadProgress(numberOfTasks: 0)
    private let syncProgress = DownloadProgress(numberOfTasks: 0)

    /// Counter for generating local external IDs when iCloud is unavailable.
    private var localIDCounter = 0

    init(dataFolder: String) {
        self.feedsZone = CloudKitFeedsZone(container: self.container)
        self.articlesZone = CloudKitArticlesZone(container: self.container)

        let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
        self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

        self.refresher = LocalAccountRefresher()
        self.refresher.delegate = self

        // Listen for iCloud account status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.iCloudAccountStatusDidChange(_:)),
            name: .iCloudAccountStatusDidChange,
            object: nil
        )
    }

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
    private func generateLocalExternalID() -> String {
        self.localIDCounter += 1
        return "local-\(UUID().uuidString)"
    }

    func receiveRemoteNotification(for _: DataStore, userInfo: [AnyHashable: Any]) async {
        await withCheckedContinuation { continuation in
            let op = CloudKitRemoteNotificationOperation(
                feedsZone: feedsZone,
                articlesZone: articlesZone,
                userInfo: userInfo
            )
            op.completionBlock = { _ in
                continuation.resume()
            }
            self.mainThreadOperationQueue.add(op)
        }
    }

    func refreshAll(for dataStore: DataStore) async throws {
        guard self.syncProgress.isComplete else {
            return
        }

        guard NetworkMonitor.shared.isConnected else {
            return
        }

        try await standardRefreshAll(for: dataStore)
    }

    func syncArticleStatus(for dataStore: DataStore) async throws {
        try await self.sendArticleStatus(for: dataStore)
        try await self.refreshArticleStatus(for: dataStore)
    }

    func sendArticleStatus(for dataStore: DataStore) async throws {
        try await self.sendArticleStatus(dataStore: dataStore, showProgress: false)
    }

    func refreshArticleStatus(for _: DataStore) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone)
            op.completionBlock = { mainThreadOperaion in
                if mainThreadOperaion.isCanceled {
                    continuation.resume(throwing: CloudKitSyncProviderError.unknown)
                } else {
                    continuation.resume(returning: ())
                }
            }
            self.mainThreadOperationQueue.add(op)
        }
    }

    func importOPML(for dataStore: DataStore, opmlFile: URL) async throws {
        guard self.syncProgress.isComplete else {
            return
        }

        let opmlData = try Data(contentsOf: opmlFile)
        let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
        let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)

        // TODO: throw appropriate error if OPML file is empty.
        guard let opmlItems = opmlDocument.children, let rootExternalID = dataStore.externalID else {
            return
        }
        let normalizedItems = OPMLNormalizer.normalize(opmlItems)

        self.syncProgress.addTask()
        defer { syncProgress.completeTask() }

        do {
            try await self.feedsZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
            try? await standardRefreshAll(for: dataStore)
        } catch {
            throw error
        }
    }

    @discardableResult
    func createFeed(
        for dataStore: DataStore,
        url urlString: String,
        name: String?,
        container: Container,
        validateFeed: Bool
    ) async throws
        -> Feed
    {
        guard let url = URL(string: urlString) else {
            throw DataStoreError.invalidParameter
        }

        let editedName = name == nil || name!.isEmpty ? nil : name
        return try await createRSSFeed(
            for: dataStore,
            url: url,
            editedName: editedName,
            container: container,
            validateFeed: validateFeed
        )
    }

    func renameFeed(for dataStore: DataStore, with feed: Feed, to name: String) async throws {
        let editedName = name.isEmpty ? nil : name

        // Rename locally first
        let oldEditedName = feed.editedName
        feed.editedName = name

        // Try to sync to CloudKit
        guard let externalID = feed.externalID else {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable, !externalID.hasPrefix("local-") {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                try await self.feedsZone.renameFeed(feed, editedName: editedName)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueRenameFeedOperation(feedExternalID: externalID, editedName: editedName)
                    DZLog("iCloud: Queued renameFeed operation for later sync")
                } else {
                    // Revert local change on non-recoverable error
                    feed.editedName = oldEditedName
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else if !externalID.hasPrefix("local-") {
            queueRenameFeedOperation(feedExternalID: externalID, editedName: editedName)
            DZLog("iCloud: Renamed feed locally, queued for sync when iCloud available")
        }
    }

    func removeFeed(dataStore: DataStore, feed: Feed, container: Container) async throws {
        let feedExternalID = feed.externalID
        let containerExternalID = container.externalID

        // Remove locally first
        dataStore.clearFeedMetadata(feed)
        container.removeFeedFromTreeAtTopLevel(feed)

        // Try to sync to CloudKit (only if we have real external IDs)
        guard
            let feedExtID = feedExternalID, let containerExtID = containerExternalID,
            !feedExtID.hasPrefix("local-") else
        {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable {
            do {
                try await removeFeedFromCloud(for: dataStore, with: feed, from: container)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueDeleteFeedOperation(feedExternalID: feedExtID, containerExternalID: containerExtID)
                    DZLog("iCloud: Queued removeFeed operation for later sync")
                } else if case CloudKitZoneError.corruptAccount = error {
                    // Ignore - feed already removed locally
                } else {
                    // Log but don't throw - local removal already done
                    DZLog(
                        "iCloud: Remove feed CloudKit error (local removal succeeded): \(error.localizedDescription)"
                    )
                }
            }
        } else {
            queueDeleteFeedOperation(feedExternalID: feedExtID, containerExternalID: containerExtID)
            DZLog("iCloud: Removed feed locally, queued for sync when iCloud available")
        }
    }

    func moveFeed(
        dataStore: DataStore,
        feed: Feed,
        sourceContainer: Container,
        destinationContainer: Container
    ) async throws {
        // Move locally first
        sourceContainer.removeFeedFromTreeAtTopLevel(feed)
        destinationContainer.addFeedToTreeAtTopLevel(feed)

        // Try to sync to CloudKit
        guard
            let feedExternalID = feed.externalID,
            let sourceExtID = sourceContainer.externalID,
            let destExtID = destinationContainer.externalID,
            !feedExternalID.hasPrefix("local-") else
        {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                try await self.feedsZone.moveFeed(feed, from: sourceContainer, to: destinationContainer)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueMoveFeedOperation(
                        feedExternalID: feedExternalID,
                        fromContainerExternalID: sourceExtID,
                        toContainerExternalID: destExtID
                    )
                    DZLog("iCloud: Queued moveFeed operation for later sync")
                } else {
                    // Revert local change
                    destinationContainer.removeFeedFromTreeAtTopLevel(feed)
                    sourceContainer.addFeedToTreeAtTopLevel(feed)
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else {
            queueMoveFeedOperation(
                feedExternalID: feedExternalID,
                fromContainerExternalID: sourceExtID,
                toContainerExternalID: destExtID
            )
            DZLog("iCloud: Moved feed locally, queued for sync when iCloud available")
        }
    }

    func addFeed(dataStore: DataStore, feed: Feed, container: Container) async throws {
        // Add locally first
        container.addFeedToTreeAtTopLevel(feed)

        // Try to sync to CloudKit
        guard
            let feedExternalID = feed.externalID,
            let containerExternalID = container.externalID,
            !feedExternalID.hasPrefix("local-") else
        {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                try await self.feedsZone.addFeed(feed, to: container)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueAddFeedToFolderOperation(
                        feedExternalID: feedExternalID,
                        containerExternalID: containerExternalID
                    )
                    DZLog("iCloud: Queued addFeed operation for later sync")
                } else {
                    container.removeFeedFromTreeAtTopLevel(feed)
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else {
            queueAddFeedToFolderOperation(feedExternalID: feedExternalID, containerExternalID: containerExternalID)
            DZLog("iCloud: Added feed locally, queued for sync when iCloud available")
        }
    }

    func restoreFeed(for dataStore: DataStore, feed: Feed, container: any Container) async throws {
        try await self.createFeed(
            for: dataStore,
            url: feed.url,
            name: feed.editedName,
            container: container,
            validateFeed: true
        )
    }

    func createFolder(for dataStore: DataStore, name: String) async throws -> Folder {
        // Create folder locally first
        guard let folder = dataStore.ensureFolder(with: name) else {
            throw DataStoreError.invalidParameter
        }

        // Assign temporary local ID if iCloud is not available
        let localExternalID = self.generateLocalExternalID()
        folder.externalID = localExternalID

        // Try to sync to CloudKit
        if iCloudAccountMonitor.shared.isAvailable {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                let externalID = try await feedsZone.createFolder(name: name)
                folder.externalID = externalID
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    // Queue the operation for later
                    queueCreateFolderOperation(name: name, localFolderID: localExternalID)
                    DZLog("iCloud: Queued createFolder operation for later sync")
                } else {
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else {
            // Queue the operation for when iCloud becomes available
            queueCreateFolderOperation(name: name, localFolderID: localExternalID)
            DZLog("iCloud: Created folder locally, queued for sync when iCloud available")
        }

        return folder
    }

    func renameFolder(for dataStore: DataStore, with folder: Folder, to name: String) async throws {
        // Rename locally first
        let oldName = folder.name
        folder.name = name

        // Try to sync to CloudKit
        guard let externalID = folder.externalID else {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable, !externalID.hasPrefix("local-") {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                try await self.feedsZone.renameFolder(folder, to: name)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueRenameFolderOperation(folderExternalID: externalID, name: name)
                    DZLog("iCloud: Queued renameFolder operation for later sync")
                } else {
                    // Revert local change on non-recoverable error
                    folder.name = oldName
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else if !externalID.hasPrefix("local-") {
            // Queue if iCloud not available but we have a real external ID
            queueRenameFolderOperation(folderExternalID: externalID, name: name)
            DZLog("iCloud: Renamed folder locally, queued for sync when iCloud available")
        }
        // If the folder has a local-only ID, the rename will be synced when the folder is created
    }

    func removeFolder(for dataStore: DataStore, with folder: Folder) async throws {
        self.syncProgress.addTask()

        let feedExternalIDs: [String]
        do {
            feedExternalIDs = try await self.feedsZone.findFeedExternalIDs(for: folder)
            self.syncProgress.completeTask()
        } catch {
            self.syncProgress.completeTask()
            self.syncProgress.completeTask()
            processSyncError(dataStore, error)
            throw error
        }

        let feeds = feedExternalIDs.compactMap { dataStore.existingFeed(withExternalID: $0) }
        var errorOccurred = false

        await withTaskGroup(of: Result<Void, Error>.self) { group in
            for feed in feeds {
                group.addTask {
                    do {
                        try await self.removeFeedFromCloud(for: dataStore, with: feed, from: folder)
                        return .success(())
                    } catch {
                        DZLog("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                if case .failure = result {
                    errorOccurred = true
                }
            }
        }

        guard !errorOccurred else {
            self.syncProgress.completeTask()
            throw CloudKitSyncProviderError.unknown
        }

        do {
            try await self.feedsZone.removeFolder(folder)
            self.syncProgress.completeTask()
            dataStore.removeFolderFromTree(folder)
        } catch {
            self.syncProgress.completeTask()
            throw error
        }
    }

    func restoreFolder(for dataStore: DataStore, folder: Folder) async throws {
        guard let name = folder.name else {
            throw DataStoreError.invalidParameter
        }

        let feedsToRestore = folder.topLevelFeeds
        self.syncProgress.addTasks(1 + feedsToRestore.count)

        do {
            let externalID = try await feedsZone.createFolder(name: name)
            self.syncProgress.completeTask()

            folder.externalID = externalID
            dataStore.addFolderToTree(folder)

            await withTaskGroup(of: Void.self) { group in
                for feed in feedsToRestore {
                    folder.topLevelFeeds.remove(feed)

                    group.addTask {
                        do {
                            try await self.restoreFeed(for: dataStore, feed: feed, container: folder)
                            self.syncProgress.completeTask()
                        } catch {
                            DZLog("CloudKit: Restore folder feed error: \(error.localizedDescription)")
                            self.syncProgress.completeTask()
                        }
                    }
                }
            }

            dataStore.addFolderToTree(folder)
        } catch {
            self.syncProgress.completeTask()
            processSyncError(dataStore, error)
            throw error
        }
    }

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

// MARK: - Private

extension CloudKitSyncProvider {
    private func initialRefreshAll(for dataStore: DataStore) async throws {
        try await self.performRefreshAll(for: dataStore, sendArticleStatus: false)
    }

    private func standardRefreshAll(for dataStore: DataStore) async throws {
        try await self.performRefreshAll(for: dataStore, sendArticleStatus: true)
    }

    private func performRefreshAll(for dataStore: DataStore, sendArticleStatus: Bool) async throws {
        self.syncProgress.addTasks(3)

        // Try CloudKit sync if iCloud is available
        if iCloudAccountMonitor.shared.isAvailable {
            do {
                try await self.feedsZone.fetchChangesInZone()
                self.syncProgress.completeTask()

                try await self.refreshArticleStatus(for: dataStore)
                self.syncProgress.completeTask()
            } catch {
                // Handle CloudKit errors gracefully
                self.syncProgress.completeTask()
                self.syncProgress.completeTask()

                if iCloudAccountMonitor.isRecoverableError(error) {
                    DZLog("iCloud: Sync skipped due to recoverable error, will retry later")
                } else {
                    self.processSyncError(dataStore, error)
                    // Only throw for non-recoverable errors that aren't auth-related
                    if
                        let ckError = (error as? CloudKitError)?.error as? CKError,
                        ckError.code != .notAuthenticated, ckError.code != .permissionFailure
                    {
                        throw error
                    }
                }
            }
        } else {
            // iCloud not available - skip CloudKit sync silently
            self.syncProgress.completeTask()
            self.syncProgress.completeTask()
            DZLog("iCloud: Skipping sync (iCloud not available)")
        }

        // Always refresh local feeds
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

    private func createRSSFeed(
        for dataStore: DataStore,
        url: URL,
        editedName: String?,
        container: Container,
        validateFeed: Bool
    ) async throws
        -> Feed
    {
        // Find the feed URL - this may fail if the URL doesn't contain a valid feed
        let feedSpecifiers: Set<FeedSpecifier>
        do {
            feedSpecifiers = try await FeedFinder.find(url: url)
        } catch {
            if validateFeed {
                throw DataStoreError.createErrorNotFound
            } else {
                return try await self.addDeadFeed(
                    dataStore: dataStore,
                    url: url,
                    editedName: editedName,
                    container: container
                )
            }
        }

        guard
            let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
            let feedURL = URL(string: bestFeedSpecifier.urlString) else
        {
            if validateFeed {
                throw DataStoreError.createErrorNotFound
            } else {
                return try await self.addDeadFeed(
                    dataStore: dataStore,
                    url: url,
                    editedName: editedName,
                    container: container
                )
            }
        }

        if dataStore.hasFeed(withURL: bestFeedSpecifier.urlString) {
            throw DataStoreError.createErrorAlreadySubscribed
        }

        // Create and sync the feed - errors here (e.g., CloudKit errors) should propagate
        return try await self.createAndSyncFeed(
            dataStore: dataStore,
            feedURL: feedURL,
            bestFeedSpecifier: bestFeedSpecifier,
            editedName: editedName,
            container: container
        )
    }

    private func createAndSyncFeed(
        dataStore: DataStore,
        feedURL: URL,
        bestFeedSpecifier: FeedSpecifier,
        editedName: String?,
        container: Container
    ) async throws
        -> Feed
    {
        let feed = dataStore.createFeed(
            with: nil,
            url: feedURL.absoluteString,
            feedID: feedURL.absoluteString,
            homePageURL: nil
        )
        feed.editedName = editedName
        container.addFeedToTreeAtTopLevel(feed)

        // Assign temporary local external ID
        let localExternalID = self.generateLocalExternalID()
        feed.externalID = localExternalID

        // Download and parse the feed (this must succeed)
        let parsedFeed: ParsedFeed
        do {
            parsedFeed = try await self.downloadAndParseFeed(feedURL: feedURL, feed: feed)
        } catch {
            container.removeFeedFromTreeAtTopLevel(feed)
            throw error
        }

        // Update the feed with parsed content
        let _ = try await dataStore.updateAsync(feed: feed, parsedFeed: parsedFeed)

        // Try to sync to CloudKit
        await self.syncFeedToCloud(
            dataStore: dataStore,
            feed: feed,
            parsedFeed: parsedFeed,
            bestFeedSpecifier: bestFeedSpecifier,
            editedName: editedName,
            container: container,
            localExternalID: localExternalID
        )

        return feed
    }

    /// Attempts to sync a feed to CloudKit. On recoverable error, queues the operation.
    private func syncFeedToCloud(
        dataStore: DataStore,
        feed: Feed,
        parsedFeed: ParsedFeed,
        bestFeedSpecifier: FeedSpecifier,
        editedName: String?,
        container: Container,
        localExternalID: String
    ) async {
        guard let containerExternalID = container.externalID else {
            DZLog("iCloud: Container has no external ID, cannot sync feed")
            return
        }

        if iCloudAccountMonitor.shared.isAvailable {
            do {
                let externalID = try await feedsZone.createFeed(
                    url: bestFeedSpecifier.urlString,
                    name: parsedFeed.title,
                    editedName: editedName,
                    homePageURL: parsedFeed.homePageURL,
                    container: container
                )
                feed.externalID = externalID
                self.sendNewArticlesToTheCloud(dataStore, feed)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    self.queueCreateFeedOperation(
                        url: bestFeedSpecifier.urlString,
                        name: parsedFeed.title,
                        editedName: editedName,
                        homePageURL: parsedFeed.homePageURL,
                        containerExternalID: containerExternalID,
                        localFeedID: localExternalID
                    )
                    DZLog("iCloud: Queued createFeed operation for later sync")
                } else {
                    DZLog("iCloud: Failed to sync feed to CloudKit: \(error.localizedDescription)")
                    self.processSyncError(dataStore, error)
                }
            }
        } else {
            self.queueCreateFeedOperation(
                url: bestFeedSpecifier.urlString,
                name: parsedFeed.title,
                editedName: editedName,
                homePageURL: parsedFeed.homePageURL,
                containerExternalID: containerExternalID,
                localFeedID: localExternalID
            )
            DZLog("iCloud: Created feed locally, queued for sync when iCloud available")
        }
    }

    private func downloadAndParseFeed(feedURL: URL, feed: Feed) async throws -> ParsedFeed {
        let (parsedFeed, response) = try await InitialFeedDownloader.download(feedURL)
        feed.lastCheckDate = Date()

        guard let parsedFeed else {
            throw DataStoreError.createErrorNotFound
        }

        // Save conditional GET info so that first refresh uses conditional GET.
        if
            let httpResponse = response as? HTTPURLResponse,
            let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
        {
            feed.conditionalGetInfo = conditionalGetInfo
        }

        return parsedFeed
    }

    private func addDeadFeed(
        dataStore: DataStore,
        url: URL,
        editedName: String?,
        container: Container
    ) async throws
        -> Feed
    {
        let feed = dataStore.createFeed(
            with: editedName,
            url: url.absoluteString,
            feedID: url.absoluteString,
            homePageURL: nil
        )
        container.addFeedToTreeAtTopLevel(feed)

        // Assign temporary local external ID
        let localExternalID = self.generateLocalExternalID()
        feed.externalID = localExternalID

        // Try to sync to CloudKit
        guard let containerExternalID = container.externalID else {
            return feed
        }

        if iCloudAccountMonitor.shared.isAvailable {
            do {
                let externalID = try await feedsZone.createFeed(
                    url: url.absoluteString,
                    name: editedName,
                    editedName: nil,
                    homePageURL: nil,
                    container: container
                )
                feed.externalID = externalID
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    self.queueCreateFeedOperation(
                        url: url.absoluteString,
                        name: editedName,
                        editedName: nil,
                        homePageURL: nil,
                        containerExternalID: containerExternalID,
                        localFeedID: localExternalID
                    )
                    DZLog("iCloud: Queued createFeed (dead feed) operation for later sync")
                } else {
                    DZLog("iCloud: Failed to sync dead feed to CloudKit: \(error.localizedDescription)")
                }
            }
        } else {
            self.queueCreateFeedOperation(
                url: url.absoluteString,
                name: editedName,
                editedName: nil,
                homePageURL: nil,
                containerExternalID: containerExternalID,
                localFeedID: localExternalID
            )
            DZLog("iCloud: Created dead feed locally, queued for sync when iCloud available")
        }

        return feed
    }

    private func sendNewArticlesToTheCloud(_ dataStore: DataStore, _ feed: Feed) {
        Task {
            do {
                let articles = try await dataStore.fetchArticlesAsync(.feed(feed))

                await self.storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>())

                try await self.sendArticleStatus(dataStore: dataStore, showProgress: true)
                try? await self.articlesZone.fetchChangesInZone()
            } catch {
                DZLog("CloudKit: Feed send articles error: \(error.localizedDescription)")
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

    private func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {
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

    private func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {
        guard let articles, !articles.isEmpty else {
            return
        }
        let syncStatuses = Set(articles.map { article in
            SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
        })
        try? await self.syncDatabase.insertStatuses(syncStatuses)
    }

    private func sendArticleStatus(dataStore: DataStore, showProgress: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CloudKitSendStatusOperation(
                dataStore: dataStore,
                articlesZone: articlesZone,
                refreshProgress: refreshProgress,
                showProgress: showProgress,
                database: syncDatabase
            )
            op.completionBlock = { mainThreadOperation in
                if mainThreadOperation.isCanceled {
                    continuation.resume(throwing: CloudKitSyncProviderError.unknown)
                } else {
                    continuation.resume(returning: ())
                }
            }
            self.mainThreadOperationQueue.add(op)
        }
    }

    private func removeFeedFromCloud(
        for dataStore: DataStore,
        with feed: Feed,
        from container: Container
    ) async throws {
        self.syncProgress.addTasks(2)

        do {
            _ = try await self.feedsZone.removeFeed(feed, from: container)
            self.syncProgress.completeTask()
        } catch {
            self.syncProgress.completeTask()
            self.syncProgress.completeTask()
            self.processSyncError(dataStore, error)
            throw error
        }

        guard let feedExternalID = feed.externalID else {
            self.syncProgress.completeTask()
            return
        }

        do {
            try await self.articlesZone.deleteArticles(feedExternalID)
            feed.dropConditionalGetInfo()
            self.syncProgress.completeTask()
        } catch {
            self.syncProgress.completeTask()
            self.processSyncError(dataStore, error)
            throw error
        }
    }

    // MARK: - Pending Operations Queue

    private func queueCreateFeedOperation(
        url: String,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        containerExternalID: String,
        localFeedID: String
    ) {
        let payload = PendingCloudKitOperation.CreateFeedPayload(
            url: url,
            name: name,
            editedName: editedName,
            homePageURL: homePageURL,
            containerExternalID: containerExternalID,
            localFeedID: localFeedID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .createFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueDeleteFeedOperation(feedExternalID: String, containerExternalID: String) {
        let payload = PendingCloudKitOperation.DeleteFeedPayload(
            feedExternalID: feedExternalID,
            containerExternalID: containerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .deleteFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueRenameFeedOperation(feedExternalID: String, editedName: String?) {
        let payload = PendingCloudKitOperation.RenameFeedPayload(
            feedExternalID: feedExternalID,
            editedName: editedName
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .renameFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueMoveFeedOperation(
        feedExternalID: String,
        fromContainerExternalID: String,
        toContainerExternalID: String
    ) {
        let payload = PendingCloudKitOperation.MoveFeedPayload(
            feedExternalID: feedExternalID,
            fromContainerExternalID: fromContainerExternalID,
            toContainerExternalID: toContainerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .moveFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueAddFeedToFolderOperation(feedExternalID: String, containerExternalID: String) {
        let payload = PendingCloudKitOperation.AddFeedToFolderPayload(
            feedExternalID: feedExternalID,
            containerExternalID: containerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .addFeedToFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueCreateFolderOperation(name: String, localFolderID: String) {
        let payload = PendingCloudKitOperation.CreateFolderPayload(
            name: name,
            localFolderID: localFolderID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .createFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueDeleteFolderOperation(folderExternalID: String) {
        let payload = PendingCloudKitOperation.DeleteFolderPayload(
            folderExternalID: folderExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .deleteFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    private func queueRenameFolderOperation(folderExternalID: String, name: String) {
        let payload = PendingCloudKitOperation.RenameFolderPayload(
            folderExternalID: folderExternalID,
            name: name
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .renameFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    // MARK: - Process Pending Operations

    private func processPendingOperations(for dataStore: DataStore) async {
        guard iCloudAccountMonitor.shared.isAvailable else { return }

        DZLog("iCloud: Processing pending operations")

        // First, ensure we have a real dataStore external ID
        var didUpgradeDataStore = false
        if let externalID = dataStore.externalID, externalID.hasPrefix("local-") {
            do {
                let realExternalID = try await feedsZone.findOrCreateAccount()
                dataStore.externalID = realExternalID
                self.feedsZone.subscribeToZoneChanges()
                self.articlesZone.subscribeToZoneChanges()
                didUpgradeDataStore = true
                DZLog("iCloud: Upgraded dataStore to real iCloud ID")
            } catch {
                // Don't log verbose error for auth failures - this is expected when iCloud isn't fully set up
                if !iCloudAccountMonitor.isRecoverableError(error) {
                    DZLog("iCloud: Could not upgrade dataStore ID (will retry later)")
                }
                return
            }
        }

        // If we just upgraded the dataStore, do an initial sync
        if didUpgradeDataStore {
            try? await self.initialRefreshAll(for: dataStore)
        }

        // Process pending operations in batches
        let batchSize = 50
        while
            let operations = try? await syncDatabase.selectPendingOperationsForProcessing(limit: batchSize),
            !operations.isEmpty
        {
            var processedIDs = Set<String>()
            var failedIDs = Set<String>()

            for operation in operations {
                do {
                    try await self.processOperation(operation, dataStore: dataStore)
                    processedIDs.insert(operation.id)
                } catch {
                    if iCloudAccountMonitor.isRecoverableError(error) {
                        failedIDs.insert(operation.id)
                        DZLog("iCloud: Operation \(operation.operationType.rawValue) will be retried later")
                    } else {
                        // Non-recoverable error - remove from queue
                        processedIDs.insert(operation.id)
                        DZLog(
                            "iCloud: Operation \(operation.operationType.rawValue) failed permanently: \(error.localizedDescription)"
                        )
                    }
                }
            }

            // Clean up processed operations
            if !processedIDs.isEmpty {
                try? await self.syncDatabase.deletePendingOperationsSelectedForProcessing(processedIDs)
            }
            if !failedIDs.isEmpty {
                try? await self.syncDatabase.resetPendingOperationsSelectedForProcessing(failedIDs)
            }
        }

        DZLog("iCloud: Finished processing pending operations")
    }

    private func processOperation(_ operation: PendingCloudKitOperation, dataStore: DataStore) async throws {
        let decoder = JSONDecoder()

        switch operation.operationType {
        case .createFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.CreateFeedPayload.self, from: operation.payload)
            try await self.processCreateFeedOperation(payload, dataStore: dataStore)

        case .deleteFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.DeleteFeedPayload.self, from: operation.payload)
            try await self.processDeleteFeedOperation(payload, dataStore: dataStore)

        case .renameFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.RenameFeedPayload.self, from: operation.payload)
            try await self.processRenameFeedOperation(payload, dataStore: dataStore)

        case .moveFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.MoveFeedPayload.self, from: operation.payload)
            try await self.processMoveFeedOperation(payload, dataStore: dataStore)

        case .addFeedToFolder:
            let payload = try decoder.decode(
                PendingCloudKitOperation.AddFeedToFolderPayload.self,
                from: operation.payload
            )
            try await self.processAddFeedToFolderOperation(payload, dataStore: dataStore)

        case .createFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.CreateFolderPayload.self, from: operation.payload)
            try await self.processCreateFolderOperation(payload, dataStore: dataStore)

        case .deleteFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.DeleteFolderPayload.self, from: operation.payload)
            try await self.processDeleteFolderOperation(payload, dataStore: dataStore)

        case .renameFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.RenameFolderPayload.self, from: operation.payload)
            try await self.processRenameFolderOperation(payload, dataStore: dataStore)
        }
    }

    private func processCreateFeedOperation(
        _ payload: PendingCloudKitOperation.CreateFeedPayload,
        dataStore: DataStore
    ) async throws {
        // Find the container
        let container: Container
        if payload.containerExternalID == dataStore.externalID || payload.containerExternalID.hasPrefix("local-") {
            container = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
            container = folder
        } else {
            DZLog("iCloud: Cannot find container for createFeed operation")
            return
        }

        let externalID = try await feedsZone.createFeed(
            url: payload.url,
            name: payload.name,
            editedName: payload.editedName,
            homePageURL: payload.homePageURL,
            container: container
        )

        // Update the local feed with the real external ID
        if let feed = dataStore.existingFeed(withExternalID: payload.localFeedID) {
            feed.externalID = externalID
            self.sendNewArticlesToTheCloud(dataStore, feed)
        }
    }

    private func processDeleteFeedOperation(
        _ payload: PendingCloudKitOperation.DeleteFeedPayload,
        dataStore: DataStore
    ) async throws {
        // Try to delete from CloudKit using the external ID
        // If the feed doesn't exist locally, we still try to delete from CloudKit
        if let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) {
            let container: Container = if payload.containerExternalID == dataStore.externalID {
                dataStore
            } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
                folder
            } else {
                dataStore
            }
            _ = try await self.feedsZone.removeFeed(feed, from: container)
        } else {
            // Feed already deleted locally, try to delete from CloudKit directly
            try await self.feedsZone.delete(externalID: payload.feedExternalID)
        }
    }

    private func processRenameFeedOperation(
        _ payload: PendingCloudKitOperation.RenameFeedPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }
        try await self.feedsZone.renameFeed(feed, editedName: payload.editedName)
    }

    private func processMoveFeedOperation(
        _ payload: PendingCloudKitOperation.MoveFeedPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }

        let sourceContainer: Container
        if payload.fromContainerExternalID == dataStore.externalID {
            sourceContainer = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.fromContainerExternalID) {
            sourceContainer = folder
        } else {
            return
        }

        let destContainer: Container
        if payload.toContainerExternalID == dataStore.externalID {
            destContainer = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.toContainerExternalID) {
            destContainer = folder
        } else {
            return
        }

        try await self.feedsZone.moveFeed(feed, from: sourceContainer, to: destContainer)
    }

    private func processAddFeedToFolderOperation(
        _ payload: PendingCloudKitOperation.AddFeedToFolderPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }

        let container: Container
        if payload.containerExternalID == dataStore.externalID {
            container = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
            container = folder
        } else {
            return
        }

        try await self.feedsZone.addFeed(feed, to: container)
    }

    private func processCreateFolderOperation(
        _ payload: PendingCloudKitOperation.CreateFolderPayload,
        dataStore: DataStore
    ) async throws {
        let externalID = try await feedsZone.createFolder(name: payload.name)

        // Update the local folder with the real external ID
        if let folder = dataStore.existingFolder(withExternalID: payload.localFolderID) {
            folder.externalID = externalID
        }
    }

    private func processDeleteFolderOperation(
        _ payload: PendingCloudKitOperation.DeleteFolderPayload,
        dataStore: DataStore
    ) async throws {
        if let folder = dataStore.existingFolder(withExternalID: payload.folderExternalID) {
            try await self.feedsZone.removeFolder(folder)
        } else {
            // Folder already deleted locally, try to delete from CloudKit directly
            try await self.feedsZone.delete(externalID: payload.folderExternalID)
        }
    }

    private func processRenameFolderOperation(
        _ payload: PendingCloudKitOperation.RenameFolderPayload,
        dataStore: DataStore
    ) async throws {
        guard let folder = dataStore.existingFolder(withExternalID: payload.folderExternalID) else {
            return
        }
        try await self.feedsZone.renameFolder(folder, to: payload.name)
    }
}

extension CloudKitSyncProvider: LocalAccountRefresherDelegate {
    func localAccountRefresher(_: LocalAccountRefresher, articleChanges: ArticleChanges) {
        Task {
            await self.storeArticleChanges(
                new: articleChanges.new,
                updated: articleChanges.updated,
                deleted: articleChanges.deleted
            )
        }
    }
}
