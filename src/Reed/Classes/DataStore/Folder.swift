//
//  Folder.swift
//  Reed
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class Folder: SidebarItem, Container, Hashable {
    nonisolated let dataStoreID: String
    weak var dataStore: DataStore?

    var defaultReadFilterType: ReadFilterType {
        .read
    }

    var containerID: ContainerIdentifier? {
        ContainerIdentifier.folder(self.dataStoreID, self.nameForDisplay)
    }

    var sidebarItemID: SidebarItemIdentifier? {
        SidebarItemIdentifier.folder(self.dataStoreID, self.nameForDisplay)
    }

    var topLevelFeeds: Set<Feed> = .init()
    var folders: Set<Folder>? // subfolders are not supported, so this is always nil

    var name: String? {
        didSet {
            postDisplayNameDidChangeNotification()
        }
    }

    static let untitledName = NSLocalizedString("Untitled ƒ", comment: "Folder name")
    nonisolated let folderID: Int // not saved: per-run only
    var externalID: String?
    static var incrementingID = 0

    // MARK: - DisplayNameProvider

    var nameForDisplay: String {
        self.name ?? Folder.untitledName
    }

    // MARK: - UnreadCountProvider

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    func rename(to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let dataStore else {
            return
        }
        Task { @MainActor in
            do {
                try await dataStore.renameFolder(self, to: name)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Init

    init(dataStore: DataStore, name: String?) {
        self.dataStoreID = dataStore.dataStoreID
        self.dataStore = dataStore
        self.name = name

        let folderID = Folder.incrementingID
        Folder.incrementingID += 1
        self.folderID = folderID

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.childrenDidChange(_:)),
            name: .ChildrenDidChange,
            object: self
        )
    }

    // MARK: - Notifications

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if let object = note.object {
            if self.objectIsChild(object as AnyObject) {
                updateUnreadCount()
            }
        }
    }

    @objc
    func childrenDidChange(_: Notification) {
        updateUnreadCount()
    }

    // MARK: Container

    func flattenedFeeds() -> Set<Feed> {
        // Since sub-folders are not supported, it’s always the top-level feeds.
        self.topLevelFeeds
    }

    func objectIsChild(_ object: AnyObject) -> Bool {
        // Folders contain Feed objects only, at least for now.
        guard let feed = object as? Feed else {
            return false
        }
        return self.topLevelFeeds.contains(feed)
    }

    func addFeedToTreeAtTopLevel(_ feed: Feed) {
        self.topLevelFeeds.insert(feed)
        postChildrenDidChangeNotification()
    }

    func addFeeds(_ feeds: Set<Feed>) {
        guard !feeds.isEmpty else {
            return
        }
        self.topLevelFeeds.formUnion(feeds)
        postChildrenDidChangeNotification()
    }

    func removeFeedFromTreeAtTopLevel(_ feed: Feed) {
        self.topLevelFeeds.remove(feed)
        postChildrenDidChangeNotification()
    }

    func removeFeedsFromTreeAtTopLevel(_ feeds: Set<Feed>) {
        guard !feeds.isEmpty else {
            return
        }
        self.topLevelFeeds.subtract(feeds)
        postChildrenDidChangeNotification()
    }

    // MARK: - Hashable

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.folderID)
    }

    // MARK: - Equatable

    nonisolated static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs === rhs
    }
}

// MARK: - Private

extension Folder {
    private func updateUnreadCount() {
        var updatedUnreadCount = 0
        for feed in self.topLevelFeeds {
            updatedUnreadCount += feed.unreadCount
        }
        self.unreadCount = updatedUnreadCount
    }

    private func childrenContain(_ feed: Feed) -> Bool {
        self.topLevelFeeds.contains(feed)
    }
}

// MARK: - OPMLRepresentable

extension Folder: OPMLRepresentable {
    func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
        let attrExternalID = if allowCustomAttributes, let externalID {
            " nnw_externalID=\"\(externalID.escapingSpecialXMLCharacters)\""
        } else {
            ""
        }

        let escapedTitle = self.nameForDisplay.escapingSpecialXMLCharacters
        var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"\(attrExternalID)>\n"
        s = s.prepending(tabCount: indentLevel)

        var hasAtLeastOneChild = false

        for feed in self.topLevelFeeds.sorted() {
            s += feed.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
            hasAtLeastOneChild = true
        }

        if !hasAtLeastOneChild {
            s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"\(attrExternalID)/>\n"
            s = s.prepending(tabCount: indentLevel)
            return s
        }

        s = s + String(repeating: "\t", count: indentLevel) + "</outline>\n"

        return s
    }
}

// MARK: Set

@MainActor
extension Set<Folder> {
    func sorted() -> [Folder] {
        self.sorted(by: { folder1, folder2 -> Bool in
            return folder1.nameForDisplay.localizedStandardCompare(folder2.nameForDisplay) == .orderedAscending
        })
    }
}
