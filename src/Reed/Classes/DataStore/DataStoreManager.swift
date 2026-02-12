//
//  DataStoreManager.swift
//  Reed
//
//  Created by Brent Simmons on 7/18/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import RSDatabase
import RSWeb

// Main thread only.

/// Manages the data store with optional CloudKit sync.
/// All user data lives on the device and syncs via CloudKit when available.
@MainActor
public final class DataStoreManager: UnreadCountProvider {
    public static var shared = DataStoreManager()

    /// The primary data store used for all feeds and articles
    public let defaultDataStore: DataStore

    private let dataStoresFolder: String
    private let iCloudDataStoreIdentifier = "iCloud"

    public var isSuspended = false

    @MainActor public var areUnreadCountsInitialized: Bool {
        self.defaultDataStore.areUnreadCountsInitialized
    }

    public var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    /// Returns the data store as an array for API compatibility
    public var dataStores: [DataStore] {
        [self.defaultDataStore]
    }

    @MainActor public var sortedDataStores: [DataStore] {
        self.dataStores
    }

    /// Always true since we have a single data store with CloudKit sync support
    public var hasiCloudDataStore: Bool {
        true
    }

    @MainActor public var activeDataStores: [DataStore] {
        self.defaultDataStore.isActive ? [self.defaultDataStore] : []
    }

    @MainActor public var sortedActiveDataStores: [DataStore] {
        self.activeDataStores
    }

    @MainActor public var lastArticleFetchEndTime: Date? {
        self.defaultDataStore.metadata.lastArticleFetchEndTime
    }

    @MainActor
    public func existingActiveDataStore(forDisplayName displayName: String) -> DataStore? {
        self.defaultDataStore.isActive && self.defaultDataStore.nameForDisplay == displayName ? self
            .defaultDataStore : nil
    }

    @MainActor public var refreshInProgress: Bool {
        self.defaultDataStore.refreshInProgress
    }

    public let combinedRefreshProgress = CombinedRefreshProgress()

    private var isActive = false

    @MainActor
    public init() {
        self.dataStoresFolder = AppConfig.dataSubfolder(named: "DataStores").path

        // Create the data store folder
        let iCloudDataStoreFolder = (dataStoresFolder as NSString)
            .appendingPathComponent(self.iCloudDataStoreIdentifier)
        do {
            try FileManager.default.createDirectory(
                atPath: iCloudDataStoreFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            assertionFailure("Could not create folder for data store.")
            abort()
        }

        self.defaultDataStore = DataStore(
            dataFolder: iCloudDataStoreFolder,
            dataStoreID: self.iCloudDataStoreIdentifier
        )
    }

    public func start() {
        guard !self.isActive else {
            assertionFailure("start called when isActive is already true")
            return
        }
        self.isActive = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidInitialize(_:)),
            name: .UnreadCountDidInitialize,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )

        DispatchQueue.main.async {
            self.updateUnreadCount()
        }
    }

    // MARK: - API

    public func existingDataStore(dataStoreID: String) -> DataStore? {
        dataStoreID == self.iCloudDataStoreIdentifier ? self.defaultDataStore : nil
    }

    @MainActor
    public func existingContainer(with containerID: ContainerIdentifier) -> Container? {
        switch containerID {
        case let .dataStore(dataStoreID):
            return self.existingDataStore(dataStoreID: dataStoreID)
        case let .folder(_, folderName):
            return self.defaultDataStore.existingFolder(with: folderName)
        default:
            break
        }
        return nil
    }

    @MainActor
    public func existingFeed(with sidebarItemID: SidebarItemIdentifier) -> SidebarItem? {
        switch sidebarItemID {
        case let .folder(_, folderName):
            return self.defaultDataStore.existingFolder(with: folderName)
        case let .feed(_, feedID):
            return self.defaultDataStore.existingFeed(withFeedID: feedID)
        default:
            break
        }
        return nil
    }

    @MainActor
    public func suspendNetworkAll() {
        self.isSuspended = true
        self.defaultDataStore.suspendNetwork()
    }

    @MainActor
    public func suspendDatabaseAll() {
        self.defaultDataStore.suspendDatabase()
    }

    @MainActor
    public func resumeAll() {
        self.isSuspended = false
        self.defaultDataStore.resumeDatabaseAndDelegate()
        self.defaultDataStore.resume()
    }

    @MainActor
    public func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
        await self.defaultDataStore.receiveRemoteNotification(userInfo: userInfo)
    }

    public typealias ErrorHandlerCallback = @Sendable (Error) -> Void

    @MainActor
    public func refreshAllWithoutWaiting(errorHandler: ErrorHandlerCallback? = nil) {
        Task { @MainActor in
            await self.refreshAll(errorHandler: errorHandler)
        }
    }

    @MainActor
    public func refreshAll(errorHandler: ErrorHandlerCallback? = nil) async {
        guard NetworkMonitor.shared.isConnected else {
            DZLog("DataStoreManager: skipping refreshAll — not connected to internet.")
            return
        }

        self.combinedRefreshProgress.start()
        defer {
            combinedRefreshProgress.stop()
        }

        guard self.defaultDataStore.isActive else { return }

        do {
            try await self.defaultDataStore.refreshAll()
        } catch {
            errorHandler?(error)
        }
    }

    @MainActor
    public func sendArticleStatusAll() async {
        guard self.defaultDataStore.isActive else { return }
        try? await self.defaultDataStore.sendArticleStatus()
    }

    @MainActor
    public func syncArticleStatusAllWithoutWaiting() {
        Task { @MainActor in
            await self.syncArticleStatusAll()
        }
    }

    @MainActor
    public func syncArticleStatusAll() async {
        guard self.defaultDataStore.isActive else { return }
        try? await self.defaultDataStore.syncArticleStatus()
    }

    public func saveAll() {
        self.defaultDataStore.save()
    }

    @MainActor
    public func anyDataStoreHasAtLeastOneFeed() -> Bool {
        self.defaultDataStore.isActive && self.defaultDataStore.hasAtLeastOneFeed()
    }

    @MainActor
    public func anyDataStoreHasFeedWithURL(_ urlString: String) -> Bool {
        guard self.defaultDataStore.isActive else { return false }
        return self.defaultDataStore.existingFeed(withURL: urlString) != nil
    }

    // MARK: - Fetching Articles

    @MainActor
    public func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
        precondition(Thread.isMainThread)
        guard self.defaultDataStore.isActive else { return Set<Article>() }
        return try self.defaultDataStore.fetchArticles(fetchType)
    }

    @MainActor
    public func fetchArticlesAsync(_ fetchType: FetchType) async throws -> Set<Article> {
        precondition(Thread.isMainThread)
        guard self.defaultDataStore.isActive else { return Set<Article>() }
        return try await self.defaultDataStore.fetchArticlesAsync(fetchType)
    }

    /// Fetch a single article (synchronously) by dataStoreID and articleID.
    public func fetchArticle(dataStoreID: String, articleID: String) -> Article? {
        precondition(Thread.isMainThread)

        guard self.existingDataStore(dataStoreID: dataStoreID) != nil else {
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

    @MainActor
    public func fetchCountForStarredArticles() throws -> Int {
        precondition(Thread.isMainThread)
        guard self.defaultDataStore.isActive else { return 0 }
        return try self.defaultDataStore.fetchCountForStarredArticles()
    }

    // MARK: - Caches

    /// Empty caches that can reasonably be emptied — when the app moves to the background, for instance.
    public func emptyCaches() {
        self.defaultDataStore.emptyCaches()
    }

    // MARK: - Notifications

    @MainActor @objc
    func unreadCountDidInitialize(_ notification: Notification) {
        guard notification.object is DataStore else {
            return
        }
        if self.areUnreadCountsInitialized {
            postUnreadCountDidInitializeNotification()
        }
    }

    @MainActor @objc
    func unreadCountDidChange(_ notification: Notification) {
        guard notification.object is DataStore else {
            return
        }
        updateUnreadCount()
    }
}

// MARK: - Private

extension DataStoreManager {
    @MainActor
    private func updateUnreadCount() {
        self.unreadCount = self.defaultDataStore.isActive ? self.defaultDataStore.unreadCount : 0
    }
}
