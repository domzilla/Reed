//
//  DataStore.swift
//  Reed
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import UIKit

// Main thread only.

extension Notification.Name {
    static let DataStoreRefreshDidFinish = Notification.Name(rawValue: "DataStoreRefreshDidFinish")
    static let DataStoreRefreshProgressDidChange = Notification
        .Name(rawValue: "DataStoreRefreshProgressDidChange")
    static let DataStoreDidDownloadArticles = Notification.Name(rawValue: "DataStoreDidDownloadArticles")
    static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
}

enum FetchType {
    case starred(_: Int? = nil)
    case unread(_: Int? = nil)
    case today(_: Int? = nil)
    case folder(Folder, Bool)
    case feed(Feed)
    case articleIDs(Set<String>)
    case search(String)
    case searchWithArticleIDs(String, Set<String>)
}

/// The single data store for all feeds, folders, and articles.
/// Syncs automatically via CloudKit when available.
@MainActor
final class DataStore: DisplayNameProvider, UnreadCountProvider, Container, Hashable {
    // MARK: - Singleton

    static var shared: DataStore = {
        let dataStoresFolder = AppConfig.dataSubfolder(named: "DataStores").path
        let iCloudIdentifier = "iCloud"
        let iCloudFolder = (dataStoresFolder as NSString).appendingPathComponent(iCloudIdentifier)
        do {
            try FileManager.default.createDirectory(
                atPath: iCloudFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            assertionFailure("Could not create folder for data store.")
            abort()
        }
        return DataStore(dataFolder: iCloudFolder, dataStoreID: iCloudIdentifier)
    }()

    // MARK: - Manager State

    var isSuspended = false
    let combinedRefreshProgress = CombinedRefreshProgress()

    typealias ErrorHandlerCallback = @Sendable (Error) -> Void
    enum UserInfoKey {
        static let dataStore = "dataStore"
        static let newArticles = "newArticles" // DataStoreDidDownloadArticles
        static let updatedArticles = "updatedArticles" // DataStoreDidDownloadArticles
        static let statuses = "statuses" // StatusesDidChange
        static let articles = "articles" // StatusesDidChange
        static let articleIDs = "articleIDs" // StatusesDidChange
        static let statusKey = "statusKey" // StatusesDidChange
        static let statusFlag = "statusFlag" // StatusesDidChange
        static let feeds = "feeds" // DataStoreDidDownloadArticles, StatusesDidChange
        static let syncErrors = "syncErrors"
    }

    var isDeleted = false

    var containerID: ContainerIdentifier? {
        ContainerIdentifier.dataStore(self.dataStoreID)
    }

    var dataStore: DataStore? {
        self
    }

    nonisolated let dataStoreID: String
    var nameForDisplay: String {
        guard let name, !name.isEmpty else {
            return self.defaultName
        }
        return name
    }

    @MainActor var name: String? {
        get {
            self.metadata.name
        }
        set {
            let currentNameForDisplay = self.nameForDisplay
            if newValue != self.metadata.name {
                self.metadata.name = newValue
                if currentNameForDisplay != self.nameForDisplay {
                    postDisplayNameDidChangeNotification()
                }
            }
        }
    }

    let defaultName: String

    @MainActor var isActive: Bool {
        get {
            self.metadata.isActive
        }
        set {
            if newValue != self.metadata.isActive {
                self.metadata.isActive = newValue
            }
        }
    }

    var topLevelFeeds = Set<Feed>()
    var folders: Set<Folder>? = Set<Folder>()

    @MainActor var externalID: String? {
        get {
            self.metadata.externalID
        }
        set {
            self.metadata.externalID = newValue
        }
    }

    @MainActor var sortedFolders: [Folder]? {
        if let folders {
            return Array(folders)
                .sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
        }
        return nil
    }

    var feedDictionariesNeedUpdate = true
    var _idToFeedDictionary = [String: Feed]()
    var idToFeedDictionary: [String: Feed] {
        if self.feedDictionariesNeedUpdate {
            rebuildFeedDictionaries()
        }
        return self._idToFeedDictionary
    }

    var _externalIDToFeedDictionary = [String: Feed]()
    var externalIDToFeedDictionary: [String: Feed] {
        if self.feedDictionariesNeedUpdate {
            rebuildFeedDictionaries()
        }
        return self._externalIDToFeedDictionary
    }

    var flattenedFeedURLs: Set<String> {
        Set(self.flattenedFeeds().map(\.url))
    }

    @MainActor var username: String? {
        get {
            self.metadata.username
        }
        set {
            if newValue != self.metadata.username {
                self.metadata.username = newValue
            }
        }
    }

    @MainActor var endpointURL: URL? {
        get {
            self.metadata.endpointURL
        }
        set {
            if newValue != self.metadata.endpointURL {
                self.metadata.endpointURL = newValue
            }
        }
    }

    var fetchingAllUnreadCounts = false
    var areUnreadCountsInitialized = false

    let dataFolder: String
    let database: ArticlesDatabase
    var syncProvider: SyncProvider
    static let saveQueue = CoalescingQueue(name: "DataStore Save Queue", interval: 1.0)

    var unreadCounts = [String: Int]() // [feedID: Int]

    var _flattenedFeeds = Set<Feed>()
    var flattenedFeedsNeedUpdate = true
    var flattenedFeedsIDs: Set<String> {
        self.flattenedFeeds().feedIDs()
    }

    private lazy var opmlFile = OPMLFile(
        filename: (dataFolder as NSString).appendingPathComponent("Subscriptions.opml"),
        dataStore: self
    )
    private lazy var metadataFile = DataStoreMetadataFile(
        filename: (dataFolder as NSString).appendingPathComponent("Settings.plist"),
        dataStore: self
    )
    @MainActor var metadata = DataStoreMetadata() {
        didSet {
            self.syncProvider.dataStoreMetadata = self.metadata
        }
    }

    private lazy var feedMetadataFile = FeedMetadataFile(
        filename: (dataFolder as NSString).appendingPathComponent("FeedMetadata.plist"),
        dataStore: self
    )
    typealias FeedMetadataDictionary = [String: FeedMetadata]
    var feedMetadata = FeedMetadataDictionary()

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    var refreshInProgress = false {
        didSet {
            if self.refreshInProgress != oldValue {
                if !self.refreshInProgress {
                    NotificationCenter.default.post(name: .DataStoreRefreshDidFinish, object: self)
                    self.opmlFile.markAsDirty()
                }
            }
        }
    }

    var refreshProgress: DownloadProgress {
        self.syncProvider.refreshProgress
    }

    // MARK: - Init

    init(dataFolder: String, dataStoreID: String) {
        self.syncProvider = CloudKitSyncProvider(dataFolder: dataFolder)

        self.syncProvider.dataStoreMetadata = self.metadata

        self.dataStoreID = dataStoreID
        self.dataFolder = dataFolder

        let databaseFilePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
        self.database = ArticlesDatabase(
            databaseFilePath: databaseFilePath,
            accountID: dataStoreID,
            retentionStyle: .feedBased
        )

        // Default name shown in UI for the feeds section
        self.defaultName = NSLocalizedString("Feeds", comment: "Feeds")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.downloadProgressDidChange(_:)),
            name: .DownloadProgressDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.batchUpdateDidPerform(_:)),
            name: .BatchUpdateDidPerform,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.displayNameDidChange(_:)),
            name: .DisplayNameDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.childrenDidChange(_:)),
            name: .ChildrenDidChange,
            object: nil
        )

        MainActor.assumeIsolated {
            self.metadataFile.load()
            self.feedMetadataFile.load()
            self.opmlFile.load()
        }

        DispatchQueue.main.async {
            self.database.cleanupDatabaseAtStartup(subscribedToFeedIDs: self.flattenedFeedsIDs)
            self._fetchAllUnreadCounts()
        }

        MainActor.assumeIsolated {
            self.syncProvider.dataStoreDidInitialize(self)
        }
    }

    // MARK: - Sync Delegation

    func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
        await self.syncProvider.receiveRemoteNotification(for: self, userInfo: userInfo)
    }

    @MainActor
    func refreshAll() async throws {
        try await self.syncProvider.refreshAll(for: self)
    }

    @MainActor
    func sendArticleStatus() async throws {
        try await self.syncProvider.sendArticleStatus(for: self)
    }

    @MainActor
    func syncArticleStatus() async throws {
        try await self.syncProvider.syncArticleStatus(for: self)
    }

    // MARK: - OPML

    func importOPML(_ opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !self.syncProvider.isOPMLImportInProgress else {
            completion(.failure(DataStoreError.opmlImportInProgress))
            return
        }

        Task { @MainActor in
            do {
                try await self.syncProvider.importOPML(for: self, opmlFile: opmlFile)
                // Reset the last fetch date to get the article history for the added feeds.
                self.metadata.lastArticleFetchStartTime = nil
                try? await self.syncProvider.refreshAll(for: self)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Suspend/Resume

    @MainActor
    func suspendNetwork() {
        self.syncProvider.suspendNetwork()
    }

    @MainActor
    func suspendDatabase() {
        self.database.cancelAndSuspend()
        self.save()
    }

    /// Re-open the SQLite database and allow database calls.
    /// Call this *before* calling resume.
    @MainActor
    func resumeDatabaseAndDelegate() {
        self.database.resume()
        self.syncProvider.resume()
    }

    /// Reload OPML, etc.
    func resume() {
        _fetchAllUnreadCounts()
    }

    // MARK: - Data

    func save() {
        MainActor.assumeIsolated {
            self.metadataFile.save()
            self.feedMetadataFile.save()
            self.opmlFile.save()
        }
    }

    @MainActor
    func prepareForDeletion() {
        self.syncProvider.dataStoreWillBeDeleted(self)
    }

    @MainActor
    func addOPMLItems(_ items: [RDOPMLItem]) {
        for item in items {
            if let feedSpecifier = item.feedSpecifier {
                self.addFeedToTreeAtTopLevel(self.newFeed(with: feedSpecifier))
            } else {
                if let title = item.titleFromAttributes, let folder = ensureFolder(with: title) {
                    folder.externalID = item.attributes?["nnw_externalID"] as? String
                    item.children?.forEach { itemChild in
                        if let feedSpecifier = itemChild.feedSpecifier {
                            folder.addFeedToTreeAtTopLevel(self.newFeed(with: feedSpecifier))
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func loadOPMLItems(_ items: [RDOPMLItem]) {
        self.addOPMLItems(OPMLNormalizer.normalize(items))
    }

    func structureDidChange() {
        // Feeds were added or deleted. Or folders added or deleted.
        // Or feeds inside folders were added or deleted.
        self.opmlFile.markAsDirty()
        self.flattenedFeedsNeedUpdate = true
        self.feedDictionariesNeedUpdate = true
    }

    // MARK: - Marking Articles

    func markArticles(
        _ articles: Set<Article>,
        statusKey: ArticleStatus.Key,
        flag: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                try await self.syncProvider.markArticles(
                    for: self,
                    articles: articles,
                    statusKey: statusKey,
                    flag: flag
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Updating Feeds

    @discardableResult
    @MainActor
    func updateAsync(feed: Feed, parsedFeed: ParsedFeed) async throws -> ArticleChanges {
        precondition(Thread.isMainThread)

        feed.takeSettings(from: parsedFeed)
        let parsedItems = parsedFeed.items
        guard !parsedItems.isEmpty else {
            return ArticleChanges()
        }

        return try await self.updateAsync(feedID: feed.feedID, parsedItems: parsedItems)
    }

    @MainActor
    func updateAsync(
        feedID: String,
        parsedItems: Set<ParsedItem>,
        deleteOlder: Bool = true
    ) async throws
        -> ArticleChanges
    {
        precondition(Thread.isMainThread)

        let articleChanges = try await database.updateAsync(
            parsedItems: parsedItems,
            feedID: feedID,
            deleteOlder: deleteOlder
        )
        sendNotificationAbout(articleChanges)
        return articleChanges
    }

    /// Returns set of Article whose statuses did change.
    @discardableResult
    @MainActor
    func updateAsync(
        articles: Set<Article>,
        statusKey: ArticleStatus.Key,
        flag: Bool
    ) async throws
        -> Set<Article>
    {
        guard !articles.isEmpty else {
            return Set<Article>()
        }

        let updatedStatuses = try await database.markAsync(articles: articles, statusKey: statusKey, flag: flag)
        let updatedArticleIDs = updatedStatuses.articleIDs()
        let updatedArticles = Set(articles.filter { updatedArticleIDs.contains($0.articleID) })
        noteStatusesForArticlesDidChange(updatedArticles)

        return updatedArticles
    }

    // MARK: - Article Statuses

    /// Make sure statuses exist. Any existing statuses won't be touched.
    /// All created statuses will be marked as read and not starred.
    /// Sends a .StatusesDidChange notification.
    func createStatusesIfNeededAsync(articleIDs: Set<String>) async throws {
        guard !articleIDs.isEmpty else {
            return
        }
        try await self.database.createStatusesIfNeededAsync(articleIDs: articleIDs)
        noteStatusesForArticleIDsDidChange(articleIDs)
    }

    /// Mark articleIDs statuses based on statusKey and flag.
    ///
    /// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
    /// Returns a set of new article statuses.
    func markAndFetchNewAsync(
        articleIDs: Set<String>,
        statusKey: ArticleStatus.Key,
        flag: Bool
    ) async throws
        -> Set<String>
    {
        guard !articleIDs.isEmpty else {
            return Set<String>()
        }

        let newArticleStatusIDs = try await database.markAndFetchNewAsync(
            articleIDs: articleIDs,
            statusKey: statusKey,
            flag: flag
        )
        noteStatusesForArticleIDsDidChange(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
        return newArticleStatusIDs
    }

    /// Mark articleIDs as read.
    ///
    /// - Returns: Set of new article statuses.
    /// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
    @discardableResult
    func markAsReadAsync(articleIDs: Set<String>) async throws -> Set<String> {
        try await self.markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .read, flag: true)
    }

    /// Mark articleIDs as unread.
    /// - Returns: Set of new article statuses.
    /// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
    @discardableResult
    func markAsUnreadAsync(articleIDs: Set<String>) async throws -> Set<String> {
        try await self.markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .read, flag: false)
    }

    /// Mark articleIDs as starred.
    /// - Returns: Set of new article statuses.
    /// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
    @discardableResult
    func markAsStarredAsync(articleIDs: Set<String>) async throws -> Set<String> {
        try await self.markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .starred, flag: true)
    }

    /// Mark articleIDs as unstarred.
    /// - Returns: Set of new article statuses.
    /// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
    @discardableResult
    func markAsUnstarredAsync(articleIDs: Set<String>) async throws -> Set<String> {
        try await self.markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .starred, flag: false)
    }

    // Delete the articles associated with the given set of articleIDs
    func delete(articleIDs: Set<String>) async throws {
        guard !articleIDs.isEmpty else {
            return
        }
        try await self.database.deleteAsync(articleIDs: articleIDs)
    }

    /// Empty caches that can reasonably be emptied. Call when the app goes in the background, for instance.
    func emptyCaches() {
        self.database.emptyCaches()
    }

    // MARK: - Debug

    func debugDropConditionalGetInfo() {
        #if DEBUG
        for feed in self.flattenedFeeds() {
            feed.dropConditionalGetInfo()
        }
        #endif
    }

    func debugRunSearch() {
        #if DEBUG
        let t1 = Date()
        let articles = try! _fetchArticlesMatching(searchString: "Brent NetNewsWire")
        let t2 = Date()
        DZLog("\(t2.timeIntervalSince(t1))")
        DZLog("\(articles.count)")
        #endif
    }

    // MARK: - Hashable

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.dataStoreID)
    }

    // MARK: - Equatable

    nonisolated class func == (lhs: DataStore, rhs: DataStore) -> Bool {
        lhs === rhs
    }
}

// MARK: - DataStoreMetadataDelegate

@MainActor
extension DataStore: DataStoreMetadataDelegate {
    func valueDidChange(_: DataStoreMetadata, key _: DataStoreMetadata.CodingKeys) {
        self.metadataFile.markAsDirty()
    }
}

// MARK: - FeedMetadataDelegate

@MainActor
extension DataStore: FeedMetadataDelegate {
    func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys) {
        self.feedMetadataFile.markAsDirty()
        guard let feed = existingFeed(withFeedID: feedMetadata.feedID) else {
            return
        }
        feed.postFeedSettingDidChangeNotification(key)
    }
}

// MARK: - OPMLRepresentable

extension DataStore: OPMLRepresentable {
    func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
        var s = ""
        for feed in self.topLevelFeeds.sorted() {
            s += feed.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
        }
        for folder in self.folders!.sorted() {
            s += folder.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
        }
        return s
    }
}

// MARK: - Private

@MainActor
extension DataStore {
    func feedMetadata(feedURL: String, feedID: String) -> FeedMetadata {
        if let d = feedMetadata[feedURL] {
            assert(d.delegate === self)
            return d
        }
        let d = FeedMetadata(feedID: feedID)
        d.delegate = self
        self.feedMetadata[feedURL] = d
        return d
    }
}
