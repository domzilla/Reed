//
//  CloudKitArticlesZoneDelegate.swift
//  DataStore
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import DZFoundation
import Foundation
import RSCore
import RSParser
import RSWeb

final class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {
    weak var dataStore: DataStore?
    var syncDatabase: SyncDatabase
    weak var articlesZone: CloudKitArticlesZone?

    init(dataStore: DataStore, database: SyncDatabase, articlesZone: CloudKitArticlesZone) {
        self.dataStore = dataStore
        self.syncDatabase = database
        self.articlesZone = articlesZone
    }

    func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws {
        do {
            let pendingReadStatusArticleIDs = try await syncDatabase
                .selectPendingReadStatusArticleIDs() ?? Set<String>()
            let pendingStarredStatusArticleIDs = try await syncDatabase
                .selectPendingStarredStatusArticleIDs() ?? Set<String>()

            await delete(recordKeys: deleted, pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs)
            try await update(
                records: changed,
                pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
                pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs
            )
        } catch {
            DZLog("CloudKit: Error getting sync status records: \(error.localizedDescription)")
            throw CloudKitZoneError.unknown
        }
    }
}

extension CloudKitArticlesZoneDelegate {
    private func delete(recordKeys: [CloudKitRecordKey], pendingStarredStatusArticleIDs: Set<String>) async {
        let receivedRecordIDs = recordKeys.filter { $0.recordType == CloudKitArticleStatus.recordType }.map(\.recordID)
        let receivedArticleIDs = Set(receivedRecordIDs.map { self.stripPrefix($0.externalID) })
        let deletableArticleIDs = receivedArticleIDs.subtracting(pendingStarredStatusArticleIDs)

        guard !deletableArticleIDs.isEmpty else {
            return
        }

        try? await self.syncDatabase.deleteSelectedForProcessing(deletableArticleIDs)
        try? await self.dataStore?.delete(articleIDs: deletableArticleIDs)
    }

    private func update(
        records: [CKRecord],
        pendingReadStatusArticleIDs: Set<String>,
        pendingStarredStatusArticleIDs: Set<String>
    ) async throws {
        let receivedUnreadArticleIDs = Set(records.filter { $0[CloudKitArticleStatus.Fields.read] == "0" }
            .map { self.stripPrefix($0.externalID) })
        let receivedReadArticleIDs = Set(records.filter { $0[CloudKitArticleStatus.Fields.read] == "1" }
            .map { self.stripPrefix($0.externalID) })
        let receivedUnstarredArticleIDs = Set(records.filter { $0[CloudKitArticleStatus.Fields.starred] == "0" }
            .map { self.stripPrefix($0.externalID) })
        let receivedStarredArticleIDs = Set(records.filter { $0[CloudKitArticleStatus.Fields.starred] == "1" }
            .map { self.stripPrefix($0.externalID) })

        let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
        let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
        let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
        let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

        // Parse items on background thread
        let feedIDsAndItems = await Task.detached(priority: .userInitiated) {
            let parsedItems = records.compactMap { makeParsedItem($0) }
            return Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }
        }.value

        nonisolated(unsafe) var updateError: Error?

        do {
            try await self.dataStore?.markAsUnreadAsync(articleIDs: updateableUnreadArticleIDs)
        } catch {
            updateError = error
            DZLog("CloudKit: Error while storing unread statuses: \(error.localizedDescription)")
        }

        do {
            try await self.dataStore?.markAsReadAsync(articleIDs: updateableReadArticleIDs)
        } catch {
            updateError = error
            DZLog("CloudKit: Error while storing read statuses: \(error.localizedDescription)")
        }

        do {
            try await self.dataStore?.markAsUnstarredAsync(articleIDs: updateableUnstarredArticleIDs)
        } catch {
            updateError = error
            DZLog("CloudKit: Error while storing unstarred statuses: \(error.localizedDescription)")
        }

        do {
            try await self.dataStore?.markAsStarredAsync(articleIDs: updateableStarredArticleIDs)
        } catch {
            updateError = error
            DZLog("CloudKit: Error while storing starred statuses: \(error.localizedDescription)")
        }

        for (feedID, parsedItems) in feedIDsAndItems {
            do {
                guard
                    let articleChanges = try await self.dataStore?.updateAsync(
                        feedID: feedID,
                        parsedItems: parsedItems,
                        deleteOlder: false
                    ) else
                {
                    continue
                }
                guard let deletes = articleChanges.deleted, !deletes.isEmpty else {
                    continue
                }
                let syncStatuses = Set(deletes.map { SyncStatus(articleID: $0.articleID, key: .deleted, flag: true) })
                try? await self.syncDatabase.insertStatuses(syncStatuses)
            } catch {
                updateError = error
                DZLog("CloudKit: Error while storing articles: \(error.localizedDescription)")
            }
        }

        if let updateError {
            throw updateError
        }
    }

    private func stripPrefix(_ externalID: String) -> String {
        String(externalID[externalID.index(externalID.startIndex, offsetBy: 2)..<externalID.endIndex])
    }
}

nonisolated func makeParsedItem(_ articleRecord: CKRecord) -> ParsedItem? {
    guard articleRecord.recordType == CloudKitArticle.recordType else {
        return nil
    }

    var parsedAuthors = Set<ParsedAuthor>()

    let decoder = JSONDecoder()

    if let encodedParsedAuthors = articleRecord[CloudKitArticle.Fields.parsedAuthors] as? [String] {
        for encodedParsedAuthor in encodedParsedAuthors {
            if
                let data = encodedParsedAuthor.data(using: .utf8), let parsedAuthor = try? decoder.decode(
                    ParsedAuthor.self,
                    from: data
                )
            {
                parsedAuthors.insert(parsedAuthor)
            }
        }
    }

    guard
        let uniqueID = articleRecord[CloudKitArticle.Fields.uniqueID] as? String,
        let feedURL = articleRecord[CloudKitArticle.Fields.feedURL] as? String else
    {
        return nil
    }

    var contentHTML = articleRecord[CloudKitArticle.Fields.contentHTML] as? String
    if let contentHTMLData = articleRecord[CloudKitArticle.Fields.contentHTMLData] as? NSData {
        if let decompressedContentHTMLData = try? contentHTMLData.decompressed(using: .lzfse) {
            contentHTML = String(data: decompressedContentHTMLData as Data, encoding: .utf8)
        }
    }

    var contentText = articleRecord[CloudKitArticle.Fields.contentText] as? String
    if let contentTextData = articleRecord[CloudKitArticle.Fields.contentTextData] as? NSData {
        if let decompressedContentTextData = try? contentTextData.decompressed(using: .lzfse) {
            contentText = String(data: decompressedContentTextData as Data, encoding: .utf8)
        }
    }

    let parsedItem = ParsedItem(
        syncServiceID: nil,
        uniqueID: uniqueID,
        feedURL: feedURL,
        url: articleRecord[CloudKitArticle.Fields.url] as? String,
        externalURL: articleRecord[CloudKitArticle.Fields.externalURL] as? String,
        title: articleRecord[CloudKitArticle.Fields.title] as? String,
        language: nil,
        contentHTML: contentHTML,
        contentText: contentText,
        markdown: nil,
        summary: articleRecord[CloudKitArticle.Fields.summary] as? String,
        imageURL: articleRecord[CloudKitArticle.Fields.imageURL] as? String,
        bannerImageURL: articleRecord[CloudKitArticle.Fields.imageURL] as? String,
        datePublished: articleRecord[CloudKitArticle.Fields.datePublished] as? Date,
        dateModified: articleRecord[CloudKitArticle.Fields.dateModified] as? Date,
        authors: parsedAuthors,
        tags: nil,
        attachments: nil
    )

    return parsedItem
}
