//
//  DataStore+FeedFolderOperations.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import Foundation

// MARK: - Feed & Folder Operations

extension DataStore {
    // MARK: - Feed CRUD

    @MainActor
    func newFeed(with opmlFeedSpecifier: RDOPMLFeedSpecifier) -> Feed {
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

    func addFeed(_ feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.addFeed(dataStore: self, feed: feed, container: container)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func createFeed(
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

    func removeFeed(
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

    func moveFeed(
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
    func renameFeed(_ feed: Feed, name: String) async throws {
        try await self.syncProvider.renameFeed(for: self, with: feed, to: name)
    }

    func restoreFeed(_ feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.restoreFeed(for: self, feed: feed, container: container)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func clearFeedMetadata(_ feed: Feed) {
        self.feedMetadata[feed.url] = nil
    }

    // MARK: - Folder CRUD

    @discardableResult
    @MainActor
    func addFolder(_ name: String) async throws -> Folder {
        try await self.syncProvider.createFolder(for: self, name: name)
    }

    func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.removeFolder(for: self, with: folder)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func renameFolder(_ folder: Folder, to name: String) async throws {
        try await self.syncProvider.renameFolder(for: self, with: folder, to: name)
    }

    func restoreFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await self.syncProvider.restoreFolder(for: self, folder: folder)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
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
    func ensureFolder(withFolderNames folderNames: [String]) -> Folder? {
        // TODO: support subfolders, maybe, some day.
        // Since we don't, just take the last name and make sure there's a Folder.

        guard let folderName = folderNames.last else {
            return nil
        }
        return self.ensureFolder(with: folderName)
    }

    @MainActor
    func existingFolder(withDisplayName displayName: String) -> Folder? {
        self.folders?.first(where: { $0.nameForDisplay == displayName })
    }

    func existingFolder(withExternalID externalID: String) -> Folder? {
        self.folders?.first(where: { $0.externalID == externalID })
    }

    @MainActor
    func existingContainer(withExternalID externalID: String) -> Container? {
        guard self.externalID != externalID else {
            return self
        }
        return self.existingFolder(withExternalID: externalID)
    }

    func existingContainers(withFeed feed: Feed) -> [Container] {
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

    func addFolderToTree(_ folder: Folder) {
        self.folders!.insert(folder)
        postChildrenDidChangeNotification()
        self.structureDidChange()
    }
}
