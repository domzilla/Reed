//
//  CloudKitFeedsZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/29/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import Foundation
import os.log
import RSCore
import RSWeb

final class CloudKitFeedsZoneDelegate: CloudKitZoneDelegate {
    private typealias UnclaimedFeed = (
        url: URL,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        feedExternalID: String
    )
    private var newUnclaimedFeeds = [String: [UnclaimedFeed]]()
    private var existingUnclaimedFeeds = [String: [Feed]]()

    weak var dataStore: DataStore?
    weak var articlesZone: CloudKitArticlesZone?

    init(dataStore: DataStore, articlesZone: CloudKitArticlesZone) {
        self.dataStore = dataStore
        self.articlesZone = articlesZone
    }

    @MainActor
    func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws {
        for deletedRecordKey in deleted {
            switch deletedRecordKey.recordType {
            case CloudKitFeedsZone.CloudKitFeed.recordType:
                self.removeFeed(deletedRecordKey.recordID.externalID)
            case CloudKitFeedsZone.CloudKitContainer.recordType:
                self.removeContainer(deletedRecordKey.recordID.externalID)
            default:
                assertionFailure("Unknown record type: \(deletedRecordKey.recordType)")
            }
        }

        for changedRecord in changed {
            switch changedRecord.recordType {
            case CloudKitFeedsZone.CloudKitFeed.recordType:
                self.addOrUpdateFeed(changedRecord)
            case CloudKitFeedsZone.CloudKitContainer.recordType:
                self.addOrUpdateContainer(changedRecord)
            default:
                assertionFailure("Unknown record type: \(changedRecord.recordType)")
            }
        }
    }

    @MainActor
    func addOrUpdateFeed(_ record: CKRecord) {
        guard
            let dataStore,
            let urlString = record[CloudKitFeedsZone.CloudKitFeed.Fields.url] as? String,
            let containerExternalIDs = record[CloudKitFeedsZone.CloudKitFeed.Fields.containerExternalIDs] as? [String],
            let url = URL(string: urlString) else
        {
            return
        }

        let name = record[CloudKitFeedsZone.CloudKitFeed.Fields.name] as? String
        let editedName = record[CloudKitFeedsZone.CloudKitFeed.Fields.editedName] as? String
        let homePageURL = record[CloudKitFeedsZone.CloudKitFeed.Fields.homePageURL] as? String

        if let feed = dataStore.existingFeed(withExternalID: record.externalID) {
            updateFeed(
                feed,
                name: name,
                editedName: editedName,
                homePageURL: homePageURL,
                containerExternalIDs: containerExternalIDs
            )
        } else {
            for containerExternalID in containerExternalIDs {
                if let container = dataStore.existingContainer(withExternalID: containerExternalID) {
                    createFeedIfNecessary(
                        url: url,
                        name: name,
                        editedName: editedName,
                        homePageURL: homePageURL,
                        feedExternalID: record.externalID,
                        container: container
                    )
                } else {
                    addNewUnclaimedFeed(
                        url: url,
                        name: name,
                        editedName: editedName,
                        homePageURL: homePageURL,
                        feedExternalID: record.externalID,
                        containerExternalID: containerExternalID
                    )
                }
            }
        }
    }

    @MainActor
    func removeFeed(_ externalID: String) {
        if
            let feed = dataStore?.existingFeed(withExternalID: externalID),
            let containers = dataStore?.existingContainers(withFeed: feed)
        {
            for container in containers {
                feed.dropConditionalGetInfo()
                container.removeFeedFromTreeAtTopLevel(feed)
            }
        }
    }

    @MainActor
    func addOrUpdateContainer(_ record: CKRecord) {
        guard
            let dataStore,
            let name = record[CloudKitFeedsZone.CloudKitContainer.Fields.name] as? String,
            let isAccount = record[CloudKitFeedsZone.CloudKitContainer.Fields.isAccount] as? String,
            isAccount != "1" else
        {
            return
        }

        var folder = dataStore.existingFolder(withExternalID: record.externalID)
        folder?.name = name

        if folder == nil {
            folder = dataStore.ensureFolder(with: name)
            folder?.externalID = record.externalID
        }

        guard let container = folder, let containerExternalID = container.externalID else { return }

        if let newUnclaimedFeeds = newUnclaimedFeeds[containerExternalID] {
            for newUnclaimedFeed in newUnclaimedFeeds {
                createFeedIfNecessary(
                    url: newUnclaimedFeed.url,
                    name: newUnclaimedFeed.name,
                    editedName: newUnclaimedFeed.editedName,
                    homePageURL: newUnclaimedFeed.homePageURL,
                    feedExternalID: newUnclaimedFeed.feedExternalID,
                    container: container
                )
            }

            self.newUnclaimedFeeds.removeValue(forKey: containerExternalID)
        }

        if let existingUnclaimedFeeds = existingUnclaimedFeeds[containerExternalID] {
            for existingUnclaimedFeed in existingUnclaimedFeeds {
                container.addFeedToTreeAtTopLevel(existingUnclaimedFeed)
            }
            self.existingUnclaimedFeeds.removeValue(forKey: containerExternalID)
        }
    }

    @MainActor
    func removeContainer(_ externalID: String) {
        if let folder = dataStore?.existingFolder(withExternalID: externalID) {
            self.dataStore?.removeFolderFromTree(folder)
        }
    }
}

extension CloudKitFeedsZoneDelegate {
    @MainActor
    private func updateFeed(
        _ feed: Feed,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        containerExternalIDs: [String]
    ) {
        guard let dataStore else { return }

        feed.name = name
        feed.editedName = editedName
        feed.homePageURL = homePageURL

        let existingContainers = dataStore.existingContainers(withFeed: feed)
        let existingContainerExternalIds = existingContainers.compactMap(\.externalID)

        let diff = containerExternalIDs.difference(from: existingContainerExternalIds)

        for change in diff {
            switch change {
            case let .remove(_, externalID, _):
                if let container = existingContainers.first(where: { $0.externalID == externalID }) {
                    container.removeFeedFromTreeAtTopLevel(feed)
                }
            case let .insert(_, externalID, _):
                if let container = dataStore.existingContainer(withExternalID: externalID) {
                    container.addFeedToTreeAtTopLevel(feed)
                } else {
                    self.addExistingUnclaimedFeed(feed, containerExternalID: externalID)
                }
            }
        }
    }

    @MainActor
    private func createFeedIfNecessary(
        url: URL,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        feedExternalID: String,
        container: Container
    ) {
        guard let dataStore else { return }

        if dataStore.existingFeed(withExternalID: feedExternalID) != nil {
            return
        }

        let feed = dataStore.createFeed(
            with: name,
            url: url.absoluteString,
            feedID: url.absoluteString,
            homePageURL: homePageURL
        )
        feed.editedName = editedName
        feed.externalID = feedExternalID
        container.addFeedToTreeAtTopLevel(feed)
    }

    private func addNewUnclaimedFeed(
        url: URL,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        feedExternalID: String,
        containerExternalID: String
    ) {
        if var unclaimedFeeds = self.newUnclaimedFeeds[containerExternalID] {
            unclaimedFeeds.append(UnclaimedFeed(
                url: url,
                name: name,
                editedName: editedName,
                homePageURL: homePageURL,
                feedExternalID: feedExternalID
            ))
            self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
        } else {
            var unclaimedFeeds = [UnclaimedFeed]()
            unclaimedFeeds.append(UnclaimedFeed(
                url: url,
                name: name,
                editedName: editedName,
                homePageURL: homePageURL,
                feedExternalID: feedExternalID
            ))
            self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
        }
    }

    private func addExistingUnclaimedFeed(_ feed: Feed, containerExternalID: String) {
        if var unclaimedFeeds = self.existingUnclaimedFeeds[containerExternalID] {
            unclaimedFeeds.append(feed)
            self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
        } else {
            var unclaimedFeeds = [Feed]()
            unclaimedFeeds.append(feed)
            self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
        }
    }
}
