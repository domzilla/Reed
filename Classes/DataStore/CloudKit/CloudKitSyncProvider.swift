//
//  CloudKitSyncProvider.swift
//  Account
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import SystemConfiguration
import os.log
import RSCore
import RSParser
import RSWeb

enum CloudKitSyncProviderError: LocalizedError, Sendable {
	case invalidParameter
	case unknown

	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor final class CloudKitSyncProvider: SyncProvider {
	nonisolated private static let logger = cloudKitLogger

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

	init(dataFolder: String) {

		self.feedsZone = CloudKitFeedsZone(container: container)
		self.articlesZone = CloudKitArticlesZone(container: container)

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		self.refresher = LocalAccountRefresher()
		self.refresher.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: refresher.downloadProgress)
		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .DownloadProgressDidChange, object: syncProgress)
	}

	func receiveRemoteNotification(for dataStore: DataStore, userInfo: [AnyHashable : Any]) async {
		await withCheckedContinuation { continuation in
			let op = CloudKitRemoteNotificationOperation(feedsZone: feedsZone, articlesZone: articlesZone, userInfo: userInfo)
			op.completionBlock = { mainThreadOperation in
				continuation.resume()
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func refreshAll(for dataStore: DataStore) async throws {
		guard refreshProgress.isComplete else {
			return
		}

		syncProgress.reset()

		guard NetworkMonitor.shared.isConnected else {
			return
		}

		try await standardRefreshAll(for: dataStore)
	}

	func syncArticleStatus(for dataStore: DataStore) async throws {
		try await sendArticleStatus(for: dataStore)
		try await refreshArticleStatus(for: dataStore)
	}

	func sendArticleStatus(for dataStore: DataStore) async throws {
		try await sendArticleStatus(dataStore: dataStore, showProgress: false)
	}

	func refreshArticleStatus(for dataStore: DataStore) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone)
			op.completionBlock = { mainThreadOperaion in
				if mainThreadOperaion.isCanceled {
					continuation.resume(throwing: CloudKitSyncProviderError.unknown)
				} else {
					continuation.resume(returning: ())
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func importOPML(for dataStore: DataStore, opmlFile: URL) async throws {
		guard refreshProgress.isComplete else {
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

		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			try await feedsZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
			try? await standardRefreshAll(for: dataStore)
		} catch {
			throw error
		}
	}

	@discardableResult
	func createFeed(for dataStore: DataStore, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let url = URL(string: urlString) else {
			throw DataStoreError.invalidParameter
		}

		let editedName = name == nil || name!.isEmpty ? nil : name
		return try await createRSSFeed(for: dataStore, url: url, editedName: editedName, container: container, validateFeed: validateFeed)
	}

	func renameFeed(for dataStore: DataStore, with feed: Feed, to name: String) async throws {
		let editedName = name.isEmpty ? nil : name
		syncProgress.addTask()
		defer {
			syncProgress.completeTask()
		}

		do {
			try await feedsZone.renameFeed(feed, editedName: editedName)
			feed.editedName = name
		} catch {
			processSyncError(dataStore, error)
			throw error
		}
	}

	func removeFeed(dataStore: DataStore, feed: Feed, container: Container) async throws {
		do {
			try await removeFeedFromCloud(for: dataStore, with: feed, from: container)
			dataStore.clearFeedMetadata(feed)
			container.removeFeedFromTreeAtTopLevel(feed)
		} catch {
			switch error {
			case CloudKitZoneError.corruptAccount:
				// We got into a bad state and should remove the feed to clear up the bad data
				dataStore.clearFeedMetadata(feed)
				container.removeFeedFromTreeAtTopLevel(feed)
			default:
				throw error
			}
		}
	}

	func moveFeed(dataStore: DataStore, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			try await feedsZone.moveFeed(feed, from: sourceContainer, to: destinationContainer)
			sourceContainer.removeFeedFromTreeAtTopLevel(feed)
			destinationContainer.addFeedToTreeAtTopLevel(feed)
		} catch {
			processSyncError(dataStore, error)
			throw error
		}
	}

	func addFeed(dataStore: DataStore, feed: Feed, container: Container) async throws {
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			try await feedsZone.addFeed(feed, to: container)
			container.addFeedToTreeAtTopLevel(feed)
		} catch {
			processSyncError(dataStore, error)
			throw error
		}
	}

	func restoreFeed(for dataStore: DataStore, feed: Feed, container: any Container) async throws {
		try await createFeed(for: dataStore, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
	}

	func createFolder(for dataStore: DataStore, name: String) async throws -> Folder {
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			let externalID = try await feedsZone.createFolder(name: name)
			guard let folder = dataStore.ensureFolder(with: name) else {
				throw DataStoreError.invalidParameter
			}
			folder.externalID = externalID
			return folder
		} catch {
			processSyncError(dataStore, error)
			throw error
		}
	}

	func renameFolder(for dataStore: DataStore, with folder: Folder, to name: String) async throws {
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			try await feedsZone.renameFolder(folder, to: name)
			folder.name = name
		} catch {
			processSyncError(dataStore, error)
			throw error
		}
	}

	func removeFolder(for dataStore: DataStore, with folder: Folder) async throws {
		syncProgress.addTask()

		let feedExternalIDs: [String]
		do {
			feedExternalIDs = try await feedsZone.findFeedExternalIDs(for: folder)
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			syncProgress.completeTask()
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
						Self.logger.error("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
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
			syncProgress.completeTask()
			throw CloudKitSyncProviderError.unknown
		}

		do {
			try await feedsZone.removeFolder(folder)
			syncProgress.completeTask()
			dataStore.removeFolderFromTree(folder)
		} catch {
			syncProgress.completeTask()
			throw error
		}
	}

	func restoreFolder(for dataStore: DataStore, folder: Folder) async throws {
		guard let name = folder.name else {
			throw DataStoreError.invalidParameter
		}

		let feedsToRestore = folder.topLevelFeeds
		syncProgress.addTasks(1 + feedsToRestore.count)

		do {
			let externalID = try await feedsZone.createFolder(name: name)
			syncProgress.completeTask()

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
							Self.logger.error("CloudKit: Restore folder feed error: \(error.localizedDescription)")
							self.syncProgress.completeTask()
						}
					}
				}
			}

			dataStore.addFolderToTree(folder)
		} catch {
			syncProgress.completeTask()
			processSyncError(dataStore, error)
			throw error
		}
	}

	func markArticles(for dataStore: DataStore, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await dataStore.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: dataStore)
		}
	}

	func dataStoreDidInitialize(_ dataStore: DataStore) {
		self.dataStore = dataStore

		feedsZone.delegate = CloudKitFeedsZoneDelegate(dataStore: dataStore, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(dataStore: dataStore, database: syncDatabase, articlesZone: articlesZone)

		syncDatabase.resetAllSelectedForProcessing()

		// Check to see if this is a new dataStore and initialize anything we need
		if dataStore.externalID == nil {
			Task {
				do {
					let externalID = try await feedsZone.findOrCreateAccount()
					dataStore.externalID = externalID
					try? await self.initialRefreshAll(for: dataStore)
				} catch {
					Self.logger.error("CloudKit: Error adding dataStore container: \(error.localizedDescription)")
				}
			}
			feedsZone.subscribeToZoneChanges()
			articlesZone.subscribeToZoneChanges()
		}

	}

	func dataStoreWillBeDeleted(_ dataStore: DataStore) {
		feedsZone.resetChangeToken()
		articlesZone.resetChangeToken()
	}

	// MARK: - Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher.suspend()
	}

	func suspendDatabase() {
		syncDatabase.suspend()
	}

	func resume() {
		refresher.resume()
		syncDatabase.resume()
	}
}

// MARK: - Refresh Progress

private extension CloudKitSyncProvider {

	func updateRefreshProgress() {

//		refreshProgress.numberOfTasks = refresher.downloadProgress.numberOfTasks + syncProgress.numberOfTasks
//		refreshProgress.numberRemaining = refresher.downloadProgress.numberRemaining + syncProgress.numberRemaining

		// Complete?
		if refreshProgress.isComplete {
			refresher.downloadProgress.reset()
			syncProgress.reset()
		}
	}

	@objc func downloadProgressDidChange(_ note: Notification) {

		updateRefreshProgress()
	}

	@objc func syncProgressDidChange(_ note: Notification) {

		updateRefreshProgress()
	}
}

// MARK: - Private

private extension CloudKitSyncProvider {

	func initialRefreshAll(for dataStore: DataStore) async throws {
		try await performRefreshAll(for: dataStore, sendArticleStatus: false)
	}

	func standardRefreshAll(for dataStore: DataStore) async throws {
		try await performRefreshAll(for: dataStore, sendArticleStatus: true)
	}

	func performRefreshAll(for dataStore: DataStore, sendArticleStatus: Bool) async throws {
		syncProgress.addTasks(3)

		do {
			try await feedsZone.fetchChangesInZone()
			syncProgress.completeTask()

			let feeds = dataStore.flattenedFeeds()

			try await refreshArticleStatus(for: dataStore)
			syncProgress.completeTask()

			await refresher.refreshFeeds(feeds)

			if sendArticleStatus {
				try await self.sendArticleStatus(dataStore: dataStore, showProgress: true)
			}

			syncProgress.reset()
			dataStore.metadata.lastArticleFetchEndTime = Date()
		} catch {
			processSyncError(dataStore, error)
			syncProgress.reset()
			throw error
		}
	}

	func createRSSFeed(for dataStore: DataStore, url: URL, editedName: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		syncProgress.addTasks(5)

		do {
			let feedSpecifiers = try await FeedFinder.find(url: url)
			syncProgress.completeTask()

			guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
				  let feedURL = URL(string: bestFeedSpecifier.urlString) else {
				syncProgress.completeTasks(3)
				if validateFeed {
					syncProgress.completeTask()
					throw DataStoreError.createErrorNotFound
				} else {
					return try await addDeadFeed(dataStore: dataStore, url: url, editedName: editedName, container: container)
				}
			}

			if dataStore.hasFeed(withURL: bestFeedSpecifier.urlString) {
				syncProgress.completeTasks(4)
				throw DataStoreError.createErrorAlreadySubscribed
			}

			return try await createAndSyncFeed(dataStore: dataStore,
											   feedURL: feedURL,
											   bestFeedSpecifier: bestFeedSpecifier,
											   editedName: editedName,
											   container: container)
		} catch {
			syncProgress.completeTasks(3)
			if validateFeed {
				syncProgress.completeTask()
				throw DataStoreError.createErrorNotFound
			} else {
				return try await addDeadFeed(dataStore: dataStore, url: url, editedName: editedName, container: container)
			}
		}
	}

	func createAndSyncFeed(dataStore: DataStore, feedURL: URL, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws -> Feed {
		let feed = dataStore.createFeed(with: nil, url: feedURL.absoluteString, feedID: feedURL.absoluteString, homePageURL: nil)
		feed.editedName = editedName
		container.addFeedToTreeAtTopLevel(feed)

		do {
			let parsedFeed = try await downloadAndParseFeed(feedURL: feedURL, feed: feed)
			try await updateAndCreateFeedInCloud(dataStore: dataStore,
												 feed: feed,
												 parsedFeed: parsedFeed,
												 bestFeedSpecifier: bestFeedSpecifier,
												 editedName: editedName,
												 container: container)
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			syncProgress.completeTasks(3)
			throw error
		}
	}

	func downloadAndParseFeed(feedURL: URL, feed: Feed) async throws -> ParsedFeed {
		let (parsedFeed, response) = try await InitialFeedDownloader.download(feedURL)
		syncProgress.completeTask()
		feed.lastCheckDate = Date()

		guard let parsedFeed else {
			throw DataStoreError.createErrorNotFound
		}

		// Save conditional GET info so that first refresh uses conditional GET.
		if let httpResponse = response as? HTTPURLResponse,
		   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
			feed.conditionalGetInfo = conditionalGetInfo
		}

		return parsedFeed
	}

	func updateAndCreateFeedInCloud(dataStore: DataStore, feed: Feed, parsedFeed: ParsedFeed, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws {
		let _ = try await dataStore.updateAsync(feed: feed, parsedFeed: parsedFeed)

		let externalID = try await feedsZone.createFeed(url: bestFeedSpecifier.urlString,
														  name: parsedFeed.title,
														  editedName: editedName,
														  homePageURL: parsedFeed.homePageURL,
														  container: container)
		syncProgress.completeTask()
		feed.externalID = externalID
		sendNewArticlesToTheCloud(dataStore, feed)
	}

	func addDeadFeed(dataStore: DataStore, url: URL, editedName: String?, container: Container) async throws -> Feed {
		let feed = dataStore.createFeed(with: editedName, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		container.addFeedToTreeAtTopLevel(feed)

		defer { syncProgress.completeTask() }

		do {
			let externalID = try await feedsZone.createFeed(url: url.absoluteString,
															  name: editedName,
															  editedName: nil,
															  homePageURL: nil,
															  container: container)
			feed.externalID = externalID
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			throw error
		}
	}

	func sendNewArticlesToTheCloud(_ dataStore: DataStore, _ feed: Feed) {
		Task {
			do {
				let articles = try await dataStore.fetchArticlesAsync(.feed(feed))

				await storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>())
				syncProgress.completeTask()

				try await sendArticleStatus(dataStore: dataStore, showProgress: true)
				try? await articlesZone.fetchChangesInZone()
			} catch {
				Self.logger.error("CloudKit: Feed send articles error: \(error.localizedDescription)")
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

	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {
		// New records with a read status aren't really new, they just didn't have the read article stored
		await withTaskGroup(of: Void.self) { group in
			if let new = new {
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

	func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {
		guard let articles = articles, !articles.isEmpty else {
			return
		}
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		})
		try? await syncDatabase.insertStatuses(syncStatuses)
	}

	func sendArticleStatus(dataStore: DataStore, showProgress: Bool) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let op = CloudKitSendStatusOperation(dataStore: dataStore,
												 articlesZone: articlesZone,
												 refreshProgress: refreshProgress,
												 showProgress: showProgress,
												 database: syncDatabase)
			op.completionBlock = { mainThreadOperation in
				if mainThreadOperation.isCanceled {
					continuation.resume(throwing: CloudKitSyncProviderError.unknown)
				} else {
					continuation.resume(returning: ())
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func removeFeedFromCloud(for dataStore: DataStore, with feed: Feed, from container: Container) async throws {
		syncProgress.addTasks(2)

		do {
			let _ = try await feedsZone.removeFeed(feed, from: container)
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			syncProgress.completeTask()
			processSyncError(dataStore, error)
			throw error
		}

		guard let feedExternalID = feed.externalID else {
			syncProgress.completeTask()
			return
		}

		do {
			try await articlesZone.deleteArticles(feedExternalID)
			feed.dropConditionalGetInfo()
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			processSyncError(dataStore, error)
			throw error
		}
	}

}

extension CloudKitSyncProvider: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
		Task {
			await storeArticleChanges(new: articleChanges.new,
									  updated: articleChanges.updated,
									  deleted: articleChanges.deleted)
		}
	}
}
