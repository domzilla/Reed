//
//  DataStore+ContainerTree.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import Foundation

// MARK: - Container

extension DataStore {
    func flattenedFeeds() -> Set<Feed> {
        assert(Thread.isMainThread)
        if self.flattenedFeedsNeedUpdate {
            updateFlattenedFeeds()
        }
        return self._flattenedFeeds
    }

    func removeFeedFromTreeAtTopLevel(_ feed: Feed) {
        self.topLevelFeeds.remove(feed)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    func removeAllInstancesOfFeedFromTreeAtAllLevels(_ feed: Feed) {
        self.topLevelFeeds.remove(feed)

        if let folders {
            for folder in folders {
                folder.removeFeedFromTreeAtTopLevel(feed)
            }
        }

        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    func removeFeedsFromTreeAtTopLevel(_ feeds: Set<Feed>) {
        guard !feeds.isEmpty else {
            return
        }
        self.topLevelFeeds.subtract(feeds)
        self.structureDidChange()
        postChildrenDidChangeNotification()
    }

    func addFeedToTreeAtTopLevel(_ feed: Feed) {
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
}

// MARK: - Container Overrides

extension DataStore {
    func existingFeed(withFeedID feedID: String) -> Feed? {
        self.idToFeedDictionary[feedID]
    }

    func existingFeed(withExternalID externalID: String) -> Feed? {
        self.externalIDToFeedDictionary[externalID]
    }
}

// MARK: - Private Tree Utilities

@MainActor
extension DataStore {
    func updateFlattenedFeeds() {
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

    func rebuildFeedDictionaries() {
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
}
