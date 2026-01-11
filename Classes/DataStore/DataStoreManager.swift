//
//  DataStoreManager.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/18/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore
import RSWeb
import RSDatabase

// Main thread only.

/// Manages the single iCloud-synced data store.
/// All user data lives on the device and syncs via iCloud automatically.
@MainActor public final class DataStoreManager: UnreadCountProvider {
	public static var shared = DataStoreManager()

	public static let netNewsWireNewsURL = "https://netnewswire.blog/feed.xml"
	private static let jsonNetNewsWireNewsURL = "https://netnewswire.blog/feed.json"

	/// The single iCloud data store used for all data
	public let defaultDataStore: DataStore

	private let dataStoresFolder: String
	private let iCloudDataStoreIdentifier = "iCloud"

	public var isSuspended = false

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataStoreManager")

	@MainActor public var areUnreadCountsInitialized: Bool {
		defaultDataStore.areUnreadCountsInitialized
	}

	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	/// Returns the single iCloud data store
	public var dataStores: [DataStore] {
		[defaultDataStore]
	}

	@MainActor public var sortedDataStores: [DataStore] {
		dataStores
	}

	/// Always true since we only use iCloud
	public var hasiCloudDataStore: Bool {
		true
	}

	@MainActor public var activeDataStores: [DataStore] {
		defaultDataStore.isActive ? [defaultDataStore] : []
	}

	@MainActor public var sortedActiveDataStores: [DataStore] {
		activeDataStores
	}

	@MainActor public var lastArticleFetchEndTime: Date? {
		defaultDataStore.metadata.lastArticleFetchEndTime
	}

	@MainActor public func existingActiveDataStore(forDisplayName displayName: String) -> DataStore? {
		defaultDataStore.isActive && defaultDataStore.nameForDisplay == displayName ? defaultDataStore : nil
	}

	@MainActor public var refreshInProgress: Bool {
		defaultDataStore.refreshInProgress
	}

	public let combinedRefreshProgress = CombinedRefreshProgress()

	private var isActive = false

	@MainActor public init() {
		self.dataStoresFolder = AppConfig.dataSubfolder(named: "DataStores").path

		// Create the iCloud data store folder
		// Format: "2_iCloud" where 2 is the CloudKit type raw value for backward compatibility
		let iCloudDataStoreFolder = (dataStoresFolder as NSString).appendingPathComponent("2_\(iCloudDataStoreIdentifier)")
		do {
			try FileManager.default.createDirectory(atPath: iCloudDataStoreFolder, withIntermediateDirectories: true, attributes: nil)
		}
		catch {
			assertionFailure("Could not create folder for iCloud data store.")
			abort()
		}

		// Migrate data from old data store structure if needed
		Self.migrateFromLegacyDataStores(dataStoresFolder: dataStoresFolder, iCloudDataStoreFolder: iCloudDataStoreFolder)

		defaultDataStore = DataStore(dataFolder: iCloudDataStoreFolder, dataStoreID: iCloudDataStoreIdentifier)
	}

	public func start() {
		guard !isActive else {
			assertionFailure("start called when isActive is already true")
			return
		}
		isActive = true

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateUnreadCount()
		}
	}

	// MARK: - API

	public func existingDataStore(dataStoreID: String) -> DataStore? {
		return dataStoreID == iCloudDataStoreIdentifier ? defaultDataStore : nil
	}

	@MainActor public func existingContainer(with containerID: ContainerIdentifier) -> Container? {
		switch containerID {
		case .dataStore(let dataStoreID):
			return existingDataStore(dataStoreID: dataStoreID)
		case .folder(_, let folderName):
			return defaultDataStore.existingFolder(with: folderName)
		default:
			break
		}
		return nil
	}

	@MainActor public func existingFeed(with sidebarItemID: SidebarItemIdentifier) -> SidebarItem? {
		switch sidebarItemID {
		case .folder(_, let folderName):
			return defaultDataStore.existingFolder(with: folderName)
		case .feed(_, let feedID):
			return defaultDataStore.existingFeed(withFeedID: feedID)
		default:
			break
		}
		return nil
	}

	@MainActor public func suspendNetworkAll() {
		isSuspended = true
		defaultDataStore.suspendNetwork()
	}

	@MainActor public func suspendDatabaseAll() {
		defaultDataStore.suspendDatabase()
	}

	@MainActor public func resumeAll() {
		isSuspended = false
		defaultDataStore.resumeDatabaseAndDelegate()
		defaultDataStore.resume()
	}

	@MainActor public func receiveRemoteNotification(userInfo: [AnyHashable : Any]) async {
		await defaultDataStore.receiveRemoteNotification(userInfo: userInfo)
	}

	public typealias ErrorHandlerCallback = @Sendable (Error) -> Void

	@MainActor public func refreshAllWithoutWaiting(errorHandler: ErrorHandlerCallback? = nil) {
		Task { @MainActor in
			await refreshAll(errorHandler: errorHandler)
		}
	}

	@MainActor public func refreshAll(errorHandler: ErrorHandlerCallback? = nil) async {
		guard NetworkMonitor.shared.isConnected else {
			Self.logger.info("DataStoreManager: skipping refreshAll — not connected to internet.")
			return
		}

		combinedRefreshProgress.start()
		defer {
			combinedRefreshProgress.stop()
		}

		guard defaultDataStore.isActive else { return }

		do {
			try await defaultDataStore.refreshAll()
		} catch {
			errorHandler?(error)
		}
	}

	@MainActor public func sendArticleStatusAll() async {
		guard defaultDataStore.isActive else { return }
		try? await defaultDataStore.sendArticleStatus()
	}

	@MainActor public func syncArticleStatusAllWithoutWaiting() {
		Task { @MainActor in
			await syncArticleStatusAll()
		}
	}

	@MainActor public func syncArticleStatusAll() async {
		guard defaultDataStore.isActive else { return }
		try? await defaultDataStore.syncArticleStatus()
	}

	public func saveAll() {
		defaultDataStore.save()
	}

	@MainActor public func anyDataStoreHasAtLeastOneFeed() -> Bool {
		defaultDataStore.isActive && defaultDataStore.hasAtLeastOneFeed()
	}

	@MainActor public func anyDataStoreHasNetNewsWireNewsSubscription() -> Bool {
		anyDataStoreHasFeedWithURL(Self.netNewsWireNewsURL) || anyDataStoreHasFeedWithURL(Self.jsonNetNewsWireNewsURL)
	}

	@MainActor public func anyDataStoreHasFeedWithURL(_ urlString: String) -> Bool {
		guard defaultDataStore.isActive else { return false }
		return defaultDataStore.existingFeed(withURL: urlString) != nil
	}

	// MARK: - Fetching Articles

	@MainActor public func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
		precondition(Thread.isMainThread)
		guard defaultDataStore.isActive else { return Set<Article>() }
		return try defaultDataStore.fetchArticles(fetchType)
	}

	@MainActor public func fetchArticlesAsync(_ fetchType: FetchType) async throws -> Set<Article> {
		precondition(Thread.isMainThread)
		guard defaultDataStore.isActive else { return Set<Article>() }
		return try await defaultDataStore.fetchArticlesAsync(fetchType)
	}

	/// Fetch a single article (synchronously) by dataStoreID and articleID.
	public func fetchArticle(dataStoreID: String, articleID: String) -> Article? {
		precondition(Thread.isMainThread)

		guard existingDataStore(dataStoreID: dataStoreID) != nil else {
			return nil
		}

		do {
			let articles = try defaultDataStore.fetchArticles(.articleIDs(Set([articleID])))
			return articles.first
		} catch {
			return nil
		}
	}

	// MARK: - Fetching Article Counts

	@MainActor public func fetchCountForStarredArticles() throws -> Int {
		precondition(Thread.isMainThread)
		guard defaultDataStore.isActive else { return 0 }
		return try defaultDataStore.fetchCountForStarredArticles()
	}

	// MARK: - Caches

	/// Empty caches that can reasonably be emptied — when the app moves to the background, for instance.
	public func emptyCaches() {
		defaultDataStore.emptyCaches()
	}

	// MARK: - Notifications

	@MainActor @objc func unreadCountDidInitialize(_ notification: Notification) {
		guard notification.object is DataStore else {
			return
		}
		if areUnreadCountsInitialized {
			postUnreadCountDidInitializeNotification()
		}
	}

	@MainActor @objc func unreadCountDidChange(_ notification: Notification) {
		guard notification.object is DataStore else {
			return
		}
		updateUnreadCount()
	}
}

// MARK: - Private

private extension DataStoreManager {

	@MainActor func updateUnreadCount() {
		unreadCount = defaultDataStore.isActive ? defaultDataStore.unreadCount : 0
	}

	/// Migrates data from old multi-data-store structure to single iCloud data store
	static func migrateFromLegacyDataStores(dataStoresFolder: String, iCloudDataStoreFolder: String) {
		let fileManager = FileManager.default

		// Check if migration is needed - look for old data store folders
		guard let contents = try? fileManager.contentsOfDirectory(atPath: dataStoresFolder) else {
			return
		}

		// Check if the iCloud folder already has data (already migrated)
		let opmlPath = (iCloudDataStoreFolder as NSString).appendingPathComponent("Subscriptions.opml")
		if fileManager.fileExists(atPath: opmlPath) {
			// Already has data, clean up old folders
			cleanupLegacyDataStoreFolders(dataStoresFolder: dataStoresFolder, iCloudDataStoreFolder: iCloudDataStoreFolder, contents: contents)
			return
		}

		// First priority: migrate from existing CloudKit data store
		for item in contents {
			let itemPath = (dataStoresFolder as NSString).appendingPathComponent(item)
			if item.hasPrefix("2_") { // CloudKit data store type
				migrateDataStoreData(from: itemPath, to: iCloudDataStoreFolder)
				cleanupLegacyDataStoreFolders(dataStoresFolder: dataStoresFolder, iCloudDataStoreFolder: iCloudDataStoreFolder, contents: contents)
				return
			}
		}

		// Second priority: migrate from local "OnMyMac" data store
		let onMyMacPath = (dataStoresFolder as NSString).appendingPathComponent("OnMyMac")
		if fileManager.fileExists(atPath: onMyMacPath) {
			migrateDataStoreData(from: onMyMacPath, to: iCloudDataStoreFolder)
			cleanupLegacyDataStoreFolders(dataStoresFolder: dataStoresFolder, iCloudDataStoreFolder: iCloudDataStoreFolder, contents: contents)
			return
		}

		// Third priority: migrate from any local data store (1_*)
		for item in contents {
			let itemPath = (dataStoresFolder as NSString).appendingPathComponent(item)
			if item.hasPrefix("1_") { // onMyMac data store type
				migrateDataStoreData(from: itemPath, to: iCloudDataStoreFolder)
				cleanupLegacyDataStoreFolders(dataStoresFolder: dataStoresFolder, iCloudDataStoreFolder: iCloudDataStoreFolder, contents: contents)
				return
			}
		}
	}

	static func migrateDataStoreData(from sourcePath: String, to destPath: String) {
		let fileManager = FileManager.default

		// Files to migrate
		let filesToMigrate = [
			"Subscriptions.opml",
			"FeedMetadata.plist",
			"DB.sqlite3",
			"DB.sqlite3-shm",
			"DB.sqlite3-wal",
			"Sync.sqlite3",
			"Sync.sqlite3-shm",
			"Sync.sqlite3-wal"
		]

		for filename in filesToMigrate {
			let sourceFile = (sourcePath as NSString).appendingPathComponent(filename)
			let destFile = (destPath as NSString).appendingPathComponent(filename)

			if fileManager.fileExists(atPath: sourceFile) && !fileManager.fileExists(atPath: destFile) {
				try? fileManager.copyItem(atPath: sourceFile, toPath: destFile)
			}
		}
	}

	static func cleanupLegacyDataStoreFolders(dataStoresFolder: String, iCloudDataStoreFolder: String, contents: [String]) {
		let fileManager = FileManager.default
		let iCloudFolderName = (iCloudDataStoreFolder as NSString).lastPathComponent

		for item in contents {
			// Skip the current iCloud folder
			if item == iCloudFolderName {
				continue
			}

			// Skip hidden files
			if item.hasPrefix(".") {
				continue
			}

			let itemPath = (dataStoresFolder as NSString).appendingPathComponent(item)

			// Remove old data store folders (OnMyMac, 1_*, 2_*)
			if item == "OnMyMac" || item.hasPrefix("1_") || item.hasPrefix("2_") {
				try? fileManager.removeItem(atPath: itemPath)
			}
		}
	}
}

// MARK: - Type Alias for Backward Compatibility

public typealias AccountManager = DataStoreManager

// MARK: - Backward Compatibility Extensions

public extension DataStoreManager {
	/// Backward compatible alias - returns the single iCloud data store
	var activeAccounts: [DataStore] { activeDataStores }

	/// Backward compatible alias - returns the single iCloud data store
	var sortedActiveAccounts: [DataStore] { sortedActiveDataStores }

	/// Backward compatible alias - returns the single iCloud data store
	var defaultAccount: DataStore { defaultDataStore }

	/// Backward compatible method alias
	func existingAccount(accountID: String) -> DataStore? {
		existingDataStore(dataStoreID: accountID)
	}

	/// Backward compatible method alias
	func anyAccountHasNetNewsWireNewsSubscription() -> Bool {
		anyDataStoreHasNetNewsWireNewsSubscription()
	}

	/// Backward compatible method alias
	func fetchArticle(accountID: String, articleID: String) -> Article? {
		fetchArticle(dataStoreID: accountID, articleID: articleID)
	}
}
