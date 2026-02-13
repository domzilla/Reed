//
//  PendingCloudKitOperation.swift
//  Reed
//
//  Created by Claude on 1/11/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Represents a CloudKit operation that needs to be performed when iCloud becomes available.
struct PendingCloudKitOperation: Hashable, Equatable, Sendable {
    /// The types of operations that can be queued.
    enum OperationType: String, Sendable {
        case createFeed
        case deleteFeed
        case renameFeed
        case moveFeed
        case addFeedToFolder
        case createFolder
        case deleteFolder
        case renameFolder
    }

    let id: String
    let operationType: OperationType
    let payload: Data // JSON-encoded operation parameters
    let createdAt: Date
    let selected: Bool

    nonisolated init(
        id: String = UUID().uuidString,
        operationType: OperationType,
        payload: Data,
        createdAt: Date = Date(),
        selected: Bool = false
    ) {
        self.id = id
        self.operationType = operationType
        self.payload = payload
        self.createdAt = createdAt
        self.selected = selected
    }

    nonisolated func databaseDictionary() -> DatabaseDictionary {
        [
            PendingOperationKey.id: self.id,
            PendingOperationKey.operationType: self.operationType.rawValue,
            PendingOperationKey.payload: self.payload,
            PendingOperationKey.createdAt: self.createdAt.timeIntervalSince1970,
            PendingOperationKey.selected: self.selected,
        ]
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// MARK: - Operation Payloads

extension PendingCloudKitOperation {
    struct CreateFeedPayload: Codable {
        let url: String
        let name: String?
        let editedName: String?
        let homePageURL: String?
        let containerExternalID: String
        let localFeedID: String // Temporary local ID until CloudKit sync

        init(
            url: String,
            name: String?,
            editedName: String?,
            homePageURL: String?,
            containerExternalID: String,
            localFeedID: String
        ) {
            self.url = url
            self.name = name
            self.editedName = editedName
            self.homePageURL = homePageURL
            self.containerExternalID = containerExternalID
            self.localFeedID = localFeedID
        }
    }

    struct DeleteFeedPayload: Codable {
        let feedExternalID: String
        let containerExternalID: String

        init(feedExternalID: String, containerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.containerExternalID = containerExternalID
        }
    }

    struct RenameFeedPayload: Codable {
        let feedExternalID: String
        let editedName: String?

        init(feedExternalID: String, editedName: String?) {
            self.feedExternalID = feedExternalID
            self.editedName = editedName
        }
    }

    struct MoveFeedPayload: Codable {
        let feedExternalID: String
        let fromContainerExternalID: String
        let toContainerExternalID: String

        init(feedExternalID: String, fromContainerExternalID: String, toContainerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.fromContainerExternalID = fromContainerExternalID
            self.toContainerExternalID = toContainerExternalID
        }
    }

    struct AddFeedToFolderPayload: Codable {
        let feedExternalID: String
        let containerExternalID: String

        init(feedExternalID: String, containerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.containerExternalID = containerExternalID
        }
    }

    struct CreateFolderPayload: Codable {
        let name: String
        let localFolderID: String // Temporary local ID until CloudKit sync

        init(name: String, localFolderID: String) {
            self.name = name
            self.localFolderID = localFolderID
        }
    }

    struct DeleteFolderPayload: Codable {
        let folderExternalID: String

        init(folderExternalID: String) {
            self.folderExternalID = folderExternalID
        }
    }

    struct RenameFolderPayload: Codable {
        let folderExternalID: String
        let name: String

        init(folderExternalID: String, name: String) {
            self.folderExternalID = folderExternalID
            self.name = name
        }
    }
}

// MARK: - Database Keys

struct PendingOperationKey: Sendable {
    static let id = "id"
    static let operationType = "operationType"
    static let payload = "payload"
    static let createdAt = "createdAt"
    static let selected = "selected"
}
