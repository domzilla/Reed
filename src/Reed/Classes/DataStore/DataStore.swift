//
//  DataStore.swift
//  Reed
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import RSDatabase
import RSParser
import RSWeb
import UIKit

// Main thread only.

extension Notification.Name {
    public static let DataStoreRefreshDidBegin = Notification.Name(rawValue: "DataStoreRefreshDidBegin")
    public static let DataStoreRefreshDidFinish = Notification.Name(rawValue: "DataStoreRefreshDidFinish")
    public static let DataStoreRefreshProgressDidChange = Notification
        .Name(rawValue: "DataStoreRefreshProgressDidChange")
    public static let DataStoreDidDownloadArticles = Notification.Name(rawValue: "DataStoreDidDownloadArticles")
    public static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
}

public enum FetchType {
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
public final class DataStore: DisplayNameProvider, UnreadCountProvider, Container, Hashable {
    public enum UserInfoKey {
        public static let dataStore = "dataStore"
        public static let newArticles = "newArticles" // DataStoreDidDownloadArticles
        public static let updatedArticles = "updatedArticles" // DataStoreDidDownloadArticles
        public static let statuses = "statuses" // StatusesDidChange
        public static let articles = "articles" // StatusesDidChange
        public static let articleIDs = "articleIDs" // StatusesDidChange
        public static let statusKey = "statusKey" // StatusesDidChange
        public static let statusFlag = "statusFlag" // StatusesDidChange
        public static let feeds = "feeds" // DataStoreDidDownloadArticles, StatusesDidChange
        public static let syncErrors = "syncErrors"
    }

    public var isDeleted = false

    public var containerID: ContainerIdentifier? {
        ContainerIdentifier.dataStore(self.dataStoreID)
    }

    public var dataStore: DataStore? {
        self
    }

    public nonisolated let dataStoreID: String
    public var nameForDisplay: String {
        guard let name, !name.isEmpty else {
            return self.defaultName
        }
        return name
    }

    @MainActor public var name: String? {
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

    public let defaultName: String

    @MainActor public var isActive: Bool {
        get {
            self.metadata.isActive
        }
        set {
            if newValue != self.metadata.isActive {
                self.metadata.isActive = newValue
            }
        }
    }

    public var topLevelFeeds = Set<Feed>()
    public var folders: Set<Folder>? = Set<Folder>()

    @MainActor public var externalID: String? {
        get {
            self.metadata.externalID
        }
        set {
            self.metadata.externalID = newValue
        }
    }

    @MainActor public var sortedFolders: [Folder]? {
        if let folders {
            return Array(folders)
                .sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
        }
        return nil
    }

    private var feedDictionariesNeedUpdate = true
    private var _idToFeedDictionary = [String: Feed]()
    var idToFeedDictionary: [String: Feed] {
        if self.feedDictionariesNeedUpdate {
            rebuildFeedDictionaries()
        }
        return self._idToFeedDictionary
    }

    private var _externalIDToFeedDictionary = [String: Feed]()
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

    @MainActor public var endpointURL: URL? {
        get {
            self.metadata.endpointURL
        }
        set {
            if newValue != self.metadata.endpointURL {
                self.metadata.endpointURL = newValue
            }
        }
    }

    private var fetchingAllUnreadCounts = false
    var areUnreadCountsInitialized = false

    let dataFolder: String
    let database: ArticlesDatabase
    var syncProvider: SyncProvider
    static let saveQueue = CoalescingQueue(name: "DataStore Save Queue", interval: 1.0)

    private var unreadCounts = [String: Int]() // [feedID: Int]

    private var _flattenedFeeds = Set<Feed>()
    private var flattenedFeedsNeedUpdate = true
    private var flattenedFeedsIDs: Set<String> {
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

    public var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    var refreshInProgress = false {
        didSet {
            if self.refreshInProgress != oldValue {
                if self.refreshInProgress {
                    NotificationCenter.default.post(name: .DataStoreRefreshDidBegin, object: self)
                } else {
                    NotificationCenter.default.post(name: .DataStoreRefreshDidFinish, object: self)
                    self.opmlFile.markAsDirty()
                }
            }
        }
    }

    var refreshProgress: DownloadProgress {
        self.syncProvider.refreshProgress
    }

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

    public func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
        await self.syncProvider.receiveRemoteNotification(for: self, userInfo: userInfo)
    }

    // MARK: - Refreshing

    @MainActor
    public func refreshAll() async throws {
        try await self.syncProvider.refreshAll(for: self)
    }

    // MARK: - Syncing Article Status

    @MainActor
    public func sendArticleStatus() async throws {
        try await self.syncProvider.sendArticleStatus(for: self)
    }

    @MainActor
    public func syncArticleStatus() async throws {
        try await self.syncProvider.syncArticleStatus(for: self)
    }

    // MARK: - OPML

    public func importOPML(_ opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
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
    public func suspendNetwork() {
        self.syncProvider.suspendNetwork()
    }

    @MainActor
    public func suspendDatabase() {
        self.database.cancelAndSuspend()
        self.save()
    }

    /// Re-open the SQLite database and allow database calls.
    /// Call this *before* calling resume.
    @MainActor
    public func resumeDatabaseAndDelegate() {
        self.database.resume()
        self.syncProvider.resume()
    }

    /// Reload OPML, etc.
    public func resume() {
        _fetchAllUnreadCounts()
    }

    // MARK: - Data

    public func save() {
        MainActor.assumeIsolated {
            self.metadataFile.save()
            self.feedMetadataFile.save()
            self.opmlFile.save()
        }
    }

    @MainActor
    public func prepareForDeletion() {
        self.syncProvider.dataStoreWillBeDeleted(self)
    }

    @MainActor
    func addOPMLItems(_ items: [RSOPMLItem]) {
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
    func loadOPMLItems(_ items: [RSOPMLItem]) {
        self.addOPMLItems(OPMLNormalizer.normalize(items))
    }

    public func markArticles(
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

    @MainActor
    func existingContainer(withExternalID externalID: String) -> Container? {
        guard self.externalID != externalID else {
            return self
        }
        return self.existingFolder(withExternalID: externalID)
    }

    public func existingContainers(withFeed feed: Feed) -> [Container] {
        var containers = [Container]()
        if self.topLevelFeeds.contains(feed) {
            containers.append(self)
        }
        self.folders?.forEach { folder in
            if folder.topLevelFeeds.contains(feed) {
                containers.append(folder)
            }
        }
        return containers
    }

    @discardableResult
    @MainActor
    func ensureFolder(with name: String) -> Folder? {
        // TODO: support subfolders, maybe, some day

        if name.isEmpty {
            return nil
        }

        if let folder = existingFolder(with: name) {
            return folder
        }

        let folder = Folder(dataStore: self, name: name)
        self.folders!.insert(folder)
        self.structureDidChange()

        postChildrenDidChangeNotification()
        return folder
    }

    @MainActor
    public func ensureFolder(withFolderNames folderNames: [String]) -> Folder? {
        // TODO: support subfolders, maybe, some day.
        // Since we don't, just take the last name and make sure there's a Folder.

        guard let folderName = folderNames.last else {
            return nil
        }
        return self.ensureFolder(with: folderName)
    }

    @MainActor
    public func existingFolder(withDisplayName displayName: String) -> Folder? {
        self.folders?.first(where: { $0.nameForDisplay == displayName })
    }

    public func existingFolder(withExternalID externalID: String) -> Folder? {
        self.folders?.first(where: { $0.externalID == externalID })
    }

    @MainActor
    func newFeed(with opmlFeedSpecifier: RSOPMLFeedSpecifier) -> Feed {
        let feedURL = opmlFeedSpecifier.feedURL
        let metadata = self.feedMetadata(feedURL: feedURL, feedID: feedURL)
        let feed = Feed(dataStore: self, url: opmlFeedSpecifier.feedURL, metadata: metadata)
        if let feedTitle = opmlFeedSpecifier.title {
            if feed.name == nil {
                feed.name = feedTitle
            }
        }
        return feed
    }

    @MainActor
    func addFeed(_ feed: Feed, container: Container) async throws {
        try await self.syncProvider.addFeed(dataStore: self, feed: feed, container: container)
    }

    public func addFeed(_ feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.addFeed(dataStore: self, feed: feed, container: container)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func createFeed(
        url: String,
        name: String?,
        container: Container,
        validateFeed: Bool,
        completion: @escaping (Result<Feed, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                let feed = try await syncProvider.createFeed(
                    for: self,
                    url: url,
                    name: name,
                    container: container,
                    validateFeed: validateFeed
                )
                completion(.success(feed))
            } catch {
                completion(.failure(error))
            }
        }
    }

    @MainActor
    func createFeed(with name: String?, url: String, feedID: String, homePageURL: String?) -> Feed {
        let metadata = self.feedMetadata(feedURL: url, feedID: feedID)
        let feed = Feed(dataStore: self, url: url, metadata: metadata)
        feed.name = name
        feed.homePageURL = homePageURL
        return feed
    }

    public func removeFeed(
        _ feed: Feed,
        from container: Container,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                try await self.syncProvider.removeFeed(dataStore: self, feed: feed, container: container)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func moveFeed(
        _ feed: Feed,
        from: Container,
        to: Container,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                try await self.syncProvider.moveFeed(
                    dataStore: self,
                    feed: feed,
                    sourceContainer: from,
                    destinationContainer: to
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    @MainActor
    public func renameFeed(_ feed: Feed, name: String) async throws {
        try await self.syncProvider.renameFeed(for: self, with: feed, to: name)
    }

    public func restoreFeed(_ feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.restoreFeed(for: self, feed: feed, container: container)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    @MainActor
    public func addFolder(_ name: String) async throws -> Folder {
        try await self.syncProvider.createFolder(for: self, name: name)
    }

    public func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.removeFolder(for: self, with: folder)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func renameFolder(_ folder: Folder, to name: String) async throws {
        try await self.syncProvider.renameFolder(for: self, with: folder, to: name)
    }

    public func restoreFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.restoreFolder(for: self, folder: folder)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func clearFeedMetadata(_ feed: Feed) {
        self.feedMetadata[feed.url] = nil
    }

    func addFolderToTree(_ folder: Folder) {
        self.folders!.insert(folder)
        postChildrenDidChangeNotification()
        self.structureDidChange()
    }

    public func updateUnreadCounts(feeds: Set<Feed>) {
        _fetchUnreadCounts(feeds: feeds)
    }

    // MARK: - Fetching Articles

    @MainActor
    public func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
        switch fetchType {
        case let .starred(limit):
            try _fetchStarredArticles(limit: limit)
        case let .unread(limit):
            try _fetchUnreadArticles(limit: limit)
        case let .today(limit):
            try _fetchTodayArticles(limit: limit)
        case let .folder(folder, readFilter):
            if readFilter {
                try _fetchUnreadArticles(container: folder)
            } else {
                try _fetchArticles(container: folder)
            }
        case let .feed(feed):
            try _fetchArticles(feed: feed)
        case let .articleIDs(articleIDs):
            try _fetchArticles(articleIDs: articleIDs)
        case let .search(searchString):
            try _fetchArticlesMatching(searchString: searchString)
        case let .searchWithArticleIDs(searchString, articleIDs):
            try _fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
        }
    }

    @MainActor
    public func fetchArticlesAsync(_ fetchType: FetchType) async throws -> Set<Article> {
        switch fetchType {
        case let .starred(limit):
            try await _fetchStarredArticlesAsync(limit: limit)
        case let .unread(limit):
            try await _fetchUnreadArticlesAsync(limit: limit)
        case let .today(limit):
            try await _fetchTodayArticlesAsync(limit: limit)
        case let .folder(folder, readFilter):
            if readFilter {
                try await _fetchUnreadArticlesAsync(container: folder)
            } else {
                try await _fetchArticlesAsync(container: folder)
            }
        case let .feed(feed):
            try await _fetchArticlesAsync(feed: feed)
        case let .articleIDs(articleIDs):
            try await _fetchArticlesAsync(articleIDs: articleIDs)
        case let .search(searchString):
            try await _fetchArticlesMatchingAsync(searchString: searchString)
        case let .searchWithArticleIDs(searchString, articleIDs):
            try await _fetchArticlesMatchingWithArticleIDsAsync(searchString: searchString, articleIDs: articleIDs)
        }
    }

    public func fetchUnreadCountForStarredArticlesAsync() async throws -> Int? {
        try await self.database.fetchUnreadCountForStarredArticlesAsync(feedIDs: self.flattenedFeedsIDs)
    }

    public func fetchCountForStarredArticles() throws -> Int {
        try self.database.fetchStarredArticlesCount(feedIDs: self.flattenedFeedsIDs)
    }

    public func fetchUnreadCountForTodayAsync() async throws -> Int {
        try await self.database.fetchUnreadCountForTodayAsync(feedIDs: self.flattenedFeedsIDs)
    }

    public func fetchUnreadArticleIDsAsync() async throws -> Set<String> {
        try await self.database.fetchUnreadArticleIDsAsync()
    }

    public func fetchStarredArticleIDsAsync() async throws -> Set<String> {
        try await self.database.fetchStarredArticleIDsAsync()
    }

    /// Fetch articleIDs for articles that we should have, but don't. These articles are either (starred) or (newer than
    /// the article cutoff date).
    @MainActor
    public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync() async throws
        -> Set<String>
    {
        try await self.database.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
    }

    // MARK: - Unread Counts

    public func unreadCount(for feed: Feed) -> Int {
        self.unreadCounts[feed.feedID] ?? 0
    }

    public func setUnreadCount(_ unreadCount: Int, for feed: Feed) {
        self.unreadCounts[feed.feedID] = unreadCount
    }

    public func structureDidChange() {
        // Feeds were added or deleted. Or folders added or deleted.
        // Or feeds inside folders were added or deleted.
        self.opmlFile.markAsDirty()
        self.flattenedFeedsNeedUpdate = true
        self.feedDictionariesNeedUpdate = true
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

    // MARK: - Container

    public func flattenedFeeds() -> Set<Feed> {
        assert(Thread.isMainThread)
        if self.flattenedFeedsNeedUpdate {
            updateFlattenedFeeds()
        }
        return self._flattenedFeeds
    }

    public func removeFeedFromTreeAtTopLevel(_ feed: Feed) {
        self.topLevelFeeds.remove(feed)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    public func removeAllInstancesOfFeedFromTreeAtAllLevels(_ feed: Feed) {
        self.topLevelFeeds.remove(feed)

        if let folders {
            for folder in folders {
                folder.removeFeedFromTreeAtTopLevel(feed)
            }
        }

        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    public func removeFeedsFromTreeAtTopLevel(_ feeds: Set<Feed>) {
        guard !feeds.isEmpty else {
            return
        }
        self.topLevelFeeds.subtract(feeds)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    public func addFeedToTreeAtTopLevel(_ feed: Feed) {
        self.topLevelFeeds.insert(feed)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    func addFeedIfNotInAnyFolder(_ feed: Feed) {
        if !self.flattenedFeeds().contains(feed) {
            self.addFeedToTreeAtTopLevel(feed)
        }
    }

    /// Remove the folder from this data store. Does not call sync provider.
    func removeFolderFromTree(_ folder: Folder) {
        self.folders?.remove(folder)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    // MARK: - Debug

    public func debugDropConditionalGetInfo() {
        #if DEBUG
        for feed in self.flattenedFeeds() {
            feed.dropConditionalGetInfo()
        }
        #endif
    }

    public func debugRunSearch() {
        #if DEBUG
        let t1 = Date()
        let articles = try! _fetchArticlesMatching(searchString: "Brent NetNewsWire")
        let t2 = Date()
        DZLog("\(t2.timeIntervalSince(t1))")
        DZLog("\(articles.count)")
        #endif
    }

    // MARK: - Notifications

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

    // MARK: - Hashable

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.dataStoreID)
    }

    // MARK: - Equatable

    public nonisolated class func == (lhs: DataStore, rhs: DataStore) -> Bool {
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

// MARK: - Fetching Articles (Private)

@MainActor
extension DataStore {
    // MARK: - Starred Articles

    private func _fetchStarredArticles(limit: Int? = nil) throws -> Set<Article> {
        try self.database.fetchStarredArticles(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    private func _fetchStarredArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self.database.fetchedStarredArticlesAsync(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    // MARK: - Unread Articles

    private func _fetchUnreadArticles(limit: Int? = nil) throws -> Set<Article> {
        try self._fetchUnreadArticles(container: self, limit: limit)
    }

    private func _fetchUnreadArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self._fetchUnreadArticlesAsync(container: self, limit: limit)
    }

    // MARK: - Today Articles

    private func _fetchTodayArticles(limit: Int? = nil) throws -> Set<Article> {
        try self.database.fetchTodayArticles(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    private func _fetchTodayArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self.database.fetchTodayArticlesAsync(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    // MARK: - Container Articles

    private func _fetchArticles(container: Container) throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try database.fetchArticles(feedIDs: feeds.feedIDs())
        self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        return articles
    }

    private func _fetchArticlesAsync(container: Container) async throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try await database.fetchArticlesAsync(feedIDs: feeds.feedIDs())
        self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        return articles
    }

    private func _fetchUnreadArticles(container: Container, limit: Int? = nil) throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try database.fetchUnreadArticles(feedIDs: feeds.feedIDs(), limit: limit)

        // We don't validate limit queries because they, by definition, won't correctly match the
        // complete unread state for the given container.
        if limit == nil {
            self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        }

        return articles
    }

    private func _fetchUnreadArticlesAsync(container: Container, limit: Int? = nil) async throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try await database.fetchUnreadArticlesAsync(feedIDs: feeds.feedIDs(), limit: limit)

        // We don't validate limit queries because they, by definition, won't correctly match the
        // complete unread state for the given container.
        if limit == nil {
            self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        }

        return articles
    }

    // MARK: - Feed Articles

    private func _fetchArticles(feed: Feed) throws -> Set<Article> {
        let articles = try database.fetchArticles(feedID: feed.feedID)
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    private func _fetchArticlesAsync(feed: Feed) async throws -> Set<Article> {
        let articles = try await database.fetchArticlesAsync(feedID: feed.feedID)
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    private func _fetchUnreadArticles(feed: Feed) throws -> Set<Article> {
        let articles = try database.fetchUnreadArticles(feedIDs: Set([feed.feedID]))
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    // MARK: - ArticleIDs Articles

    private func _fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
        try self.database.fetchArticles(articleIDs: articleIDs)
    }

    private func _fetchArticlesAsync(articleIDs: Set<String>) async throws -> Set<Article> {
        try await self.database.fetchArticlesAsync(articleIDs: articleIDs)
    }

    // MARK: - Search Articles

    private func _fetchArticlesMatching(searchString: String) throws -> Set<Article> {
        try self.database.fetchArticlesMatching(searchString: searchString, feedIDs: self.flattenedFeedsIDs)
    }

    private func _fetchArticlesMatchingAsync(searchString: String) async throws -> Set<Article> {
        try await self.database.fetchArticlesMatchingAsync(searchString: searchString, feedIDs: self.flattenedFeedsIDs)
    }

    private func _fetchArticlesMatchingWithArticleIDs(
        searchString: String,
        articleIDs: Set<String>
    ) throws
        -> Set<Article>
    {
        try self.database.fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
    }

    private func _fetchArticlesMatchingWithArticleIDsAsync(
        searchString: String,
        articleIDs: Set<String>
    ) async throws
        -> Set<Article>
    {
        try await self.database.fetchArticlesMatchingWithArticleIDsAsync(
            searchString: searchString,
            articleIDs: articleIDs
        )
    }

    // MARK: - Unread Counts

    private func validateUnreadCountsAfterFetchingUnreadArticles(feeds: Set<Feed>, articles: Set<Article>) {
        // Validate unread counts. This was the site of a performance slowdown:
        // it was calling going through the entire list of articles once per feed:
        // feeds.forEach { validateUnreadCount($0, articles) }
        // Now we loop through articles exactly once. This makes a huge difference.

        var unreadCountStorage = [String: Int]() // [FeedID: Int]
        for article in articles where !article.status.read {
            unreadCountStorage[article.feedID, default: 0] += 1
        }
        for feed in feeds {
            let unreadCount = unreadCountStorage[feed.feedID, default: 0]
            feed.unreadCount = unreadCount
        }
    }

    private func validateUnreadCount(feed: Feed, articles: Set<Article>) {
        // articles must contain all the unread articles for the feed.
        // The unread number should match the feed's unread count.
        var feedUnreadCount = 0
        for article in articles {
            if article.feed == feed, !article.status.read {
                feedUnreadCount += 1
            }
        }
        feed.unreadCount = feedUnreadCount
    }
}

// MARK: - Fetching Unread Counts (Private)

@MainActor
extension DataStore {
    /// Fetch unread counts for zero or more feeds.
    ///
    /// Uses the most efficient method based on how many feeds were passed in.
    private func _fetchUnreadCounts(for feeds: Set<Feed>) {
        if feeds.isEmpty {
            return
        }
        if feeds.count == 1, let feed = feeds.first {
            self._fetchUnreadCount(feed: feed)
        } else if feeds.count < 10 {
            self._fetchUnreadCounts(feeds: feeds)
        } else {
            self._fetchAllUnreadCounts()
        }
    }

    private func _fetchUnreadCount(feed: Feed) {
        Task { @MainActor in
            guard let unreadCount = try? await database.fetchUnreadCountAsync(feedID: feed.feedID) else {
                return
            }
            feed.unreadCount = unreadCount
        }
    }

    private func _fetchUnreadCounts(feeds: Set<Feed>) {
        Task { @MainActor in
            guard let unreadCountDictionary = try? await database.fetchUnreadCountsAsync(feedIDs: feeds.feedIDs()) else {
                return
            }
            self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: feeds)
        }
    }

    private func _fetchAllUnreadCounts() {
        self.fetchingAllUnreadCounts = true

        Task { @MainActor in
            guard let unreadCountDictionary = try? await database.fetchAllUnreadCountsAsync() else {
                return
            }

            self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: self.flattenedFeeds())
            self.fetchingAllUnreadCounts = false
            updateUnreadCount()

            if !self.areUnreadCountsInitialized {
                self.areUnreadCountsInitialized = true
                self.postUnreadCountDidInitializeNotification()
            }
        }
    }

    private func processUnreadCounts(unreadCountDictionary: UnreadCountDictionary, feeds: Set<Feed>) {
        for feed in feeds {
            // When the unread count is zero, it won't appear in unreadCountDictionary.
            let unreadCount = unreadCountDictionary[feed.feedID] ?? 0
            feed.unreadCount = unreadCount
        }
    }
}

// MARK: - Private

@MainActor
extension DataStore {
    private func feedMetadata(feedURL: String, feedID: String) -> FeedMetadata {
        if let d = feedMetadata[feedURL] {
            assert(d.delegate === self)
            return d
        }
        let d = FeedMetadata(feedID: feedID)
        d.delegate = self
        self.feedMetadata[feedURL] = d
        return d
    }

    private func updateFlattenedFeeds() {
        var feeds = Set<Feed>()
        feeds.formUnion(self.topLevelFeeds)
        if let folders {
            for folder in folders {
                feeds.formUnion(folder.flattenedFeeds())
            }
        }

        self._flattenedFeeds = feeds
        self.flattenedFeedsNeedUpdate = false
    }

    private func rebuildFeedDictionaries() {
        var idDictionary = [String: Feed]()
        var externalIDDictionary = [String: Feed]()

        for feed in self.flattenedFeeds() {
            idDictionary[feed.feedID] = feed
            if let externalID = feed.externalID {
                externalIDDictionary[externalID] = feed
            }
        }

        self._idToFeedDictionary = idDictionary
        self._externalIDToFeedDictionary = externalIDDictionary
        self.feedDictionariesNeedUpdate = false
    }

    private func updateUnreadCount() {
        if self.fetchingAllUnreadCounts {
            return
        }
        var updatedUnreadCount = 0
        for feed in self.flattenedFeeds() {
            updatedUnreadCount += feed.unreadCount
        }
        self.unreadCount = updatedUnreadCount
    }

    private func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
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

    private func noteStatusesForArticleIDsDidChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) {
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

    private func noteStatusesForArticleIDsDidChange(_ articleIDs: Set<String>) {
        self._fetchAllUnreadCounts()
        NotificationCenter.default.post(
            name: .StatusesDidChange,
            object: self,
            userInfo: [UserInfoKey.articleIDs: articleIDs]
        )
    }

    private func sendNotificationAbout(_ articleChanges: ArticleChanges) {
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
            NotificationCenter.default.postOnMainThread(
                name: .DataStoreDidDownloadArticles,
                object: self,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Container Overrides

extension DataStore {
    public func existingFeed(withFeedID feedID: String) -> Feed? {
        self.idToFeedDictionary[feedID]
    }

    public func existingFeed(withExternalID externalID: String) -> Feed? {
        self.externalIDToFeedDictionary[externalID]
    }
}

// MARK: - OPMLRepresentable

extension DataStore: OPMLRepresentable {
    public func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
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

// MARK: - DataStoreType

public nonisolated enum DataStoreType: Int, Codable, Sendable {
    // Raw values should not change since they're stored on disk.
    case onMyMac = 1
    case cloudKit = 2
}
