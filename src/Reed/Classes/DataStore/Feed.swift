//
//  Feed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

@MainActor
public final class Feed: SidebarItem, Renamable, Hashable {
    public nonisolated let feedID: String
    public nonisolated let dataStoreID: String
    public nonisolated let url: String
    public nonisolated let sidebarItemID: SidebarItemIdentifier?

    public weak var dataStore: DataStore?

    public var defaultReadFilterType: ReadFilterType {
        .none
    }

    public var homePageURL: String? {
        get {
            self.metadata.homePageURL
        }
        set {
            if let url = newValue, !url.isEmpty {
                self.metadata.homePageURL = url.normalizedURL
            } else {
                self.metadata.homePageURL = nil
            }
        }
    }

    // Note: this is available only if the icon URL was available in the feed.
    // The icon URL is a JSON-Feed-only feature.
    // Otherwise we find an icon URL via other means, but we don’t store it
    // as part of feed metadata.
    public var iconURL: String? {
        get {
            self.metadata.iconURL
        }
        set {
            self.metadata.iconURL = newValue
        }
    }

    // Note: this is available only if the favicon URL was available in the feed.
    // The favicon URL is a JSON-Feed-only feature.
    // Otherwise we find a favicon URL via other means, but we don’t store it
    // as part of feed metadata.
    public var faviconURL: String? {
        get {
            self.metadata.faviconURL
        }
        set {
            self.metadata.faviconURL = newValue
        }
    }

    @MainActor public var name: String? {
        didSet {
            if self.name != oldValue {
                postDisplayNameDidChangeNotification()
            }
        }
    }

    public var authors: Set<Author>? {
        get {
            if let authorsArray = metadata.authors {
                return Set(authorsArray)
            }
            return nil
        }
        set {
            if let authorsSet = newValue {
                self.metadata.authors = Array(authorsSet)
            } else {
                self.metadata.authors = nil
            }
        }
    }

    @MainActor public var editedName: String? {
        // Don’t let editedName == ""
        get {
            guard let s = metadata.editedName, !s.isEmpty else {
                return nil
            }
            return s
        }
        set {
            if newValue != editedName {
                if let valueToSet = newValue, !valueToSet.isEmpty {
                    self.metadata.editedName = valueToSet
                } else {
                    self.metadata.editedName = nil
                }
                postDisplayNameDidChangeNotification()
            }
        }
    }

    public var conditionalGetInfo: HTTPConditionalGetInfo? {
        get {
            self.metadata.conditionalGetInfo
        }
        set {
            self.metadata.conditionalGetInfo = newValue
        }
    }

    public var conditionalGetInfoDate: Date? {
        get {
            self.metadata.conditionalGetInfoDate
        }
        set {
            self.metadata.conditionalGetInfoDate = newValue
        }
    }

    public var cacheControlInfo: CacheControlInfo? {
        get {
            self.metadata.cacheControlInfo
        }
        set {
            self.metadata.cacheControlInfo = newValue
        }
    }

    public var contentHash: String? {
        get {
            self.metadata.contentHash
        }
        set {
            self.metadata.contentHash = newValue
        }
    }

    public var isNotifyAboutNewArticles: Bool? {
        get {
            self.metadata.isNotifyAboutNewArticles
        }
        set {
            self.metadata.isNotifyAboutNewArticles = newValue
        }
    }

    public var isArticleExtractorAlwaysOn: Bool? {
        get {
            self.metadata.isArticleExtractorAlwaysOn
        }
        set {
            self.metadata.isArticleExtractorAlwaysOn = newValue
        }
    }

    public var externalID: String? {
        get {
            self.metadata.externalID
        }
        set {
            self.metadata.externalID = newValue
        }
    }

    // Folder Name: Sync Service Relationship ID
    public var folderRelationship: [String: String]? {
        get {
            self.metadata.folderRelationship
        }
        set {
            self.metadata.folderRelationship = newValue
        }
    }

    /// Last time an attempt was made to read the feed.
    /// (Not necessarily a successful attempt.)
    public var lastCheckDate: Date? {
        get {
            self.metadata.lastCheckDate
        }
        set {
            self.metadata.lastCheckDate = newValue
        }
    }

    // MARK: - DisplayNameProvider

    public var nameForDisplay: String {
        if let s = editedName, !s.isEmpty {
            return s
        }
        if let s = name, !s.isEmpty {
            return s
        }
        return NSLocalizedString("Untitled", comment: "Feed name")
    }

    // MARK: - Renamable

    public func rename(to newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let dataStore else {
            return
        }
        Task { @MainActor in
            do {
                try await dataStore.renameFeed(self, name: newName)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - UnreadCountProvider

    public var unreadCount: Int {
        get {
            self.dataStore?.unreadCount(for: self) ?? 0
        }
        set {
            if unreadCount == newValue {
                return
            }
            self.dataStore?.setUnreadCount(newValue, for: self)
            postUnreadCountDidChangeNotification()
        }
    }

    // MARK: - NotificationDisplayName

    public var notificationDisplayName: String {
        if self.url.contains("www.reddit.com") {
            NSLocalizedString("Notify about new posts", comment: "notifyNameDisplay / Reddit")
        } else {
            NSLocalizedString("Notify about new articles", comment: "notifyNameDisplay / Default")
        }
    }

    var metadata: FeedMetadata

    // MARK: - Private

    // MARK: - Init

    init(dataStore: DataStore, url: String, metadata: FeedMetadata) {
        let dataStoreID = dataStore.dataStoreID
        let feedID = metadata.feedID
        self.dataStoreID = dataStoreID
        self.dataStore = dataStore
        self.feedID = feedID
        self.sidebarItemID = SidebarItemIdentifier.feed(dataStoreID, feedID)

        self.url = url
        self.metadata = metadata
    }

    // MARK: - API

    public func dropConditionalGetInfo() {
        self.conditionalGetInfo = nil
        self.contentHash = nil
    }

    // MARK: - Hashable

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.feedID)
        hasher.combine(self.dataStoreID)
    }

    // MARK: - Equatable

    public nonisolated class func == (lhs: Feed, rhs: Feed) -> Bool {
        lhs.feedID == rhs.feedID && lhs.dataStoreID == rhs.dataStoreID
    }
}

// MARK: - OPMLRepresentable

extension Feed: OPMLRepresentable {
    public func OPMLString(indentLevel: Int, allowCustomAttributes _: Bool) -> String {
        // https://github.com/brentsimmons/NetNewsWire/issues/527
        // Don’t use nameForDisplay because that can result in a feed name "Untitled" written to disk,
        // which NetNewsWire may take later to be the actual name.
        var nameToUse = self.editedName
        if nameToUse == nil {
            nameToUse = self.name
        }
        if nameToUse == nil {
            nameToUse = ""
        }
        let escapedName = nameToUse!.escapingSpecialXMLCharacters

        var escapedHomePageURL = ""
        if let homePageURL {
            escapedHomePageURL = homePageURL.escapingSpecialXMLCharacters
        }
        let escapedFeedURL = self.url.escapingSpecialXMLCharacters

        var s = "<outline text=\"\(escapedName)\" title=\"\(escapedName)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(escapedHomePageURL)\" xmlUrl=\"\(escapedFeedURL)\"/>\n"
        s = s.prepending(tabCount: indentLevel)

        return s
    }
}

@MainActor
extension Set<Feed> {
    func feedIDs() -> Set<String> {
        Set<String>(map(\.feedID))
    }

    func sorted() -> [Feed] {
        self.sorted(by: { feed1, feed2 -> Bool in
            if feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedSame {
                return feed1.url < feed2.url
            }
            return feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedAscending
        })
    }
}
