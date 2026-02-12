//
//  CloudKitSyncProvider+FeedOperations.swift
//  Reed
//
//  Extracted from CloudKitSyncProvider.swift
//

import DZFoundation
import Foundation

// MARK: - Feed Operations

extension CloudKitSyncProvider {
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
        return try await self.createRSSFeed(
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
                try await self.removeFeedFromCloud(for: dataStore, with: feed, from: container)
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

    // MARK: - Private Feed Creation Pipeline

    func createRSSFeed(
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

    func createAndSyncFeed(
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
    func syncFeedToCloud(
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

    func downloadAndParseFeed(feedURL: URL, feed: Feed) async throws -> ParsedFeed {
        let (data, response) = try await Downloader.shared.download(feedURL)
        let parsedFeed: ParsedFeed? = if let data {
            try await FeedParser.parse(ParserData(url: feedURL.absoluteString, data: data))
        } else {
            nil
        }
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

    func addDeadFeed(
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

    func sendNewArticlesToTheCloud(_ dataStore: DataStore, _ feed: Feed) {
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

    func removeFeedFromCloud(
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
}
