//
//  PendingCloudKitOperation.swift
//  Reed
//
//  Created by Claude on 1/11/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabase

/// Represents a CloudKit operation that needs to be performed when iCloud becomes available.
public struct PendingCloudKitOperation: Hashable, Equatable, Sendable {
    /// The types of operations that can be queued.
    public enum OperationType: String, Sendable {
        case createFeed
        case deleteFeed
        case renameFeed
        case moveFeed
        case addFeedToFolder
        case createFolder
        case deleteFolder
        case renameFolder
    }

    public let id: String
    public let operationType: OperationType
    public let payload: Data // JSON-encoded operation parameters
    public let createdAt: Date
    public let selected: Bool

    public nonisolated init(
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

    public nonisolated func databaseDictionary() -> DatabaseDictionary {
        [
            PendingOperationKey.id: self.id,
            PendingOperationKey.operationType: self.operationType.rawValue,
            PendingOperationKey.payload: self.payload,
            PendingOperationKey.createdAt: self.createdAt.timeIntervalSince1970,
            PendingOperationKey.selected: self.selected,
        ]
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// MARK: - Operation Payloads

extension PendingCloudKitOperation {
    public struct CreateFeedPayload: Codable {
        public let url: String
        public let name: String?
        public let editedName: String?
        public let homePageURL: String?
        public let containerExternalID: String
        public let localFeedID: String // Temporary local ID until CloudKit sync

        public init(
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

    public struct DeleteFeedPayload: Codable {
        public let feedExternalID: String
        public let containerExternalID: String

        public init(feedExternalID: String, containerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.containerExternalID = containerExternalID
        }
    }

    public struct RenameFeedPayload: Codable {
        public let feedExternalID: String
        public let editedName: String?

        public init(feedExternalID: String, editedName: String?) {
            self.feedExternalID = feedExternalID
            self.editedName = editedName
        }
    }

    public struct MoveFeedPayload: Codable {
        public let feedExternalID: String
        public let fromContainerExternalID: String
        public let toContainerExternalID: String

        public init(feedExternalID: String, fromContainerExternalID: String, toContainerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.fromContainerExternalID = fromContainerExternalID
            self.toContainerExternalID = toContainerExternalID
        }
    }

    public struct AddFeedToFolderPayload: Codable {
        public let feedExternalID: String
        public let containerExternalID: String

        public init(feedExternalID: String, containerExternalID: String) {
            self.feedExternalID = feedExternalID
            self.containerExternalID = containerExternalID
        }
    }

    public struct CreateFolderPayload: Codable {
        public let name: String
        public let localFolderID: String // Temporary local ID until CloudKit sync

        public init(name: String, localFolderID: String) {
            self.name = name
            self.localFolderID = localFolderID
        }
    }

    public struct DeleteFolderPayload: Codable {
        public let folderExternalID: String

        public init(folderExternalID: String) {
            self.folderExternalID = folderExternalID
        }
    }

    public struct RenameFolderPayload: Codable {
        public let folderExternalID: String
        public let name: String

        public init(folderExternalID: String, name: String) {
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
