//
//  DataStore+ManagerAPI.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import DZFoundation
import Foundation

// MARK: - Manager API (formerly DataStoreManager)

extension DataStore {
    /// Returns the single data store in an array (backward compat)
    var activeDataStores: [DataStore] {
        self.isActive ? [self] : []
    }

    /// Returns the single data store in an array (backward compat)
    var sortedActiveDataStores: [DataStore] {
        self.activeDataStores
    }

    var lastArticleFetchEndTime: Date? {
        self.metadata.lastArticleFetchEndTime
    }

    private var isManagerActive: Bool {
        get { self._isManagerActive }
        set { self._isManagerActive = newValue }
    }

    private static var _managerActive = false

    private var _isManagerActive: Bool {
        get { Self._managerActive }
        set { Self._managerActive = newValue }
    }

    /// Start listening for unread count changes. Called once from AppDelegate.
    func startManager() {
        guard !self.isManagerActive else {
            assertionFailure("startManager called when already active")
            return
        }
        self.isManagerActive = true

        DispatchQueue.main.async {
            // Force an initial unread count notification
            self.postUnreadCountDidChangeNotification()
        }
    }

    func existingDataStore(dataStoreID: String) -> DataStore? {
        dataStoreID == self.dataStoreID ? self : nil
    }

    func existingContainer(with containerID: ContainerIdentifier) -> Container? {
        switch containerID {
        case let .dataStore(dataStoreID):
            self.existingDataStore(dataStoreID: dataStoreID)
        case let .folder(_, folderName):
            self.existingFolder(with: folderName)
        default:
            nil
        }
    }

    func existingFeed(with sidebarItemID: SidebarItemIdentifier) -> SidebarItem? {
        switch sidebarItemID {
        case let .folder(_, folderName):
            self.existingFolder(with: folderName)
        case let .feed(_, feedID):
            self.existingFeed(withFeedID: feedID)
        default:
            nil
        }
    }

    func suspendAll() {
        self.isSuspended = true
        self.suspendNetwork()
        self.suspendDatabase()
    }

    func resumeAll() {
        self.isSuspended = false
        self.resumeDatabaseAndDelegate()
        self.resume()
    }

    func refreshAllWithoutWaiting(errorHandler: ErrorHandlerCallback? = nil) {
        Task { @MainActor in
            await self.refreshAllManaged(errorHandler: errorHandler)
        }
    }

    func refreshAllManaged(errorHandler: ErrorHandlerCallback? = nil) async {
        guard NetworkMonitor.shared.isConnected else {
            DZLog("DataStore: skipping refreshAll — not connected to internet.")
            return
        }

        self.combinedRefreshProgress.start()
        defer {
            combinedRefreshProgress.stop()
        }

        guard self.isActive else { return }

        do {
            try await self.refreshAll()
        } catch {
            errorHandler?(error)
        }
    }

    func sendArticleStatusAll() async {
        guard self.isActive else { return }
        try? await self.sendArticleStatus()
    }

    func syncArticleStatusAllWithoutWaiting() {
        Task { @MainActor in
            await self.syncArticleStatusAll()
        }
    }

    func syncArticleStatusAll() async {
        guard self.isActive else { return }
        try? await self.syncArticleStatus()
    }

    func fetchArticle(dataStoreID: String, articleID: String) -> Article? {
        precondition(Thread.isMainThread)

        guard self.existingDataStore(dataStoreID: dataStoreID) != nil else {
            return nil
        }

        do {
            let articles = try self.fetchArticles(.articleIDs(Set([articleID])))
            return articles.first
        } catch {
            return nil
        }
    }

    func anyDataStoreHasFeedWithURL(_ urlString: String) -> Bool {
        guard self.isActive else { return false }
        return self.existingFeed(withURL: urlString) != nil
    }
}
