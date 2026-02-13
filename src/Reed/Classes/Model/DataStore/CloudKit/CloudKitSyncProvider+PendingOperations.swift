//
//  CloudKitSyncProvider+PendingOperations.swift
//  Reed
//
//  Extracted from CloudKitSyncProvider.swift
//

import DZFoundation
import Foundation

// MARK: - Pending Operations Queue

extension CloudKitSyncProvider {
    func queueCreateFeedOperation(
        url: String,
        name: String?,
        editedName: String?,
        homePageURL: String?,
        containerExternalID: String,
        localFeedID: String
    ) {
        let payload = PendingCloudKitOperation.CreateFeedPayload(
            url: url,
            name: name,
            editedName: editedName,
            homePageURL: homePageURL,
            containerExternalID: containerExternalID,
            localFeedID: localFeedID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .createFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueDeleteFeedOperation(feedExternalID: String, containerExternalID: String) {
        let payload = PendingCloudKitOperation.DeleteFeedPayload(
            feedExternalID: feedExternalID,
            containerExternalID: containerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .deleteFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueRenameFeedOperation(feedExternalID: String, editedName: String?) {
        let payload = PendingCloudKitOperation.RenameFeedPayload(
            feedExternalID: feedExternalID,
            editedName: editedName
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .renameFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueMoveFeedOperation(
        feedExternalID: String,
        fromContainerExternalID: String,
        toContainerExternalID: String
    ) {
        let payload = PendingCloudKitOperation.MoveFeedPayload(
            feedExternalID: feedExternalID,
            fromContainerExternalID: fromContainerExternalID,
            toContainerExternalID: toContainerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .moveFeed, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueAddFeedToFolderOperation(feedExternalID: String, containerExternalID: String) {
        let payload = PendingCloudKitOperation.AddFeedToFolderPayload(
            feedExternalID: feedExternalID,
            containerExternalID: containerExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .addFeedToFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueCreateFolderOperation(name: String, localFolderID: String) {
        let payload = PendingCloudKitOperation.CreateFolderPayload(
            name: name,
            localFolderID: localFolderID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .createFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueDeleteFolderOperation(folderExternalID: String) {
        let payload = PendingCloudKitOperation.DeleteFolderPayload(
            folderExternalID: folderExternalID
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .deleteFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    func queueRenameFolderOperation(folderExternalID: String, name: String) {
        let payload = PendingCloudKitOperation.RenameFolderPayload(
            folderExternalID: folderExternalID,
            name: name
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let operation = PendingCloudKitOperation(operationType: .renameFolder, payload: payloadData)
        Task {
            try? await self.syncDatabase.insertPendingOperation(operation)
        }
    }

    // MARK: - Process Pending Operations

    func processPendingOperations(for dataStore: DataStore) async {
        guard iCloudAccountMonitor.shared.isAvailable else { return }

        DZLog("iCloud: Processing pending operations")

        // First, ensure we have a real dataStore external ID
        var didUpgradeDataStore = false
        if let externalID = dataStore.externalID, externalID.hasPrefix("local-") {
            do {
                let realExternalID = try await feedsZone.findOrCreateAccount()
                dataStore.externalID = realExternalID
                self.feedsZone.subscribeToZoneChanges()
                self.articlesZone.subscribeToZoneChanges()
                didUpgradeDataStore = true
                DZLog("iCloud: Upgraded dataStore to real iCloud ID")
            } catch {
                // Don't log verbose error for auth failures - this is expected when iCloud isn't fully set up
                if !iCloudAccountMonitor.isRecoverableError(error) {
                    DZLog("iCloud: Could not upgrade dataStore ID (will retry later)")
                }
                return
            }
        }

        // If we just upgraded the dataStore, do an initial sync
        if didUpgradeDataStore {
            await self.initialRefreshAll(for: dataStore)
        }

        // Process pending operations in batches
        let batchSize = 50
        while
            let operations = try? await syncDatabase.selectPendingOperationsForProcessing(limit: batchSize),
            !operations.isEmpty
        {
            var processedIDs = Set<String>()
            var failedIDs = Set<String>()

            for operation in operations {
                do {
                    try await self.processOperation(operation, dataStore: dataStore)
                    processedIDs.insert(operation.id)
                } catch {
                    if iCloudAccountMonitor.isRecoverableError(error) {
                        failedIDs.insert(operation.id)
                        DZLog("iCloud: Operation \(operation.operationType.rawValue) will be retried later")
                    } else {
                        // Non-recoverable error - remove from queue
                        processedIDs.insert(operation.id)
                        DZLog(
                            "iCloud: Operation \(operation.operationType.rawValue) failed permanently: \(error.localizedDescription)"
                        )
                    }
                }
            }

            // Clean up processed operations
            if !processedIDs.isEmpty {
                try? await self.syncDatabase.deletePendingOperationsSelectedForProcessing(processedIDs)
            }
            if !failedIDs.isEmpty {
                try? await self.syncDatabase.resetPendingOperationsSelectedForProcessing(failedIDs)
            }
        }

        DZLog("iCloud: Finished processing pending operations")
    }

    func processOperation(_ operation: PendingCloudKitOperation, dataStore: DataStore) async throws {
        let decoder = JSONDecoder()

        switch operation.operationType {
        case .createFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.CreateFeedPayload.self, from: operation.payload)
            try await self.processCreateFeedOperation(payload, dataStore: dataStore)

        case .deleteFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.DeleteFeedPayload.self, from: operation.payload)
            try await self.processDeleteFeedOperation(payload, dataStore: dataStore)

        case .renameFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.RenameFeedPayload.self, from: operation.payload)
            try await self.processRenameFeedOperation(payload, dataStore: dataStore)

        case .moveFeed:
            let payload = try decoder.decode(PendingCloudKitOperation.MoveFeedPayload.self, from: operation.payload)
            try await self.processMoveFeedOperation(payload, dataStore: dataStore)

        case .addFeedToFolder:
            let payload = try decoder.decode(
                PendingCloudKitOperation.AddFeedToFolderPayload.self,
                from: operation.payload
            )
            try await self.processAddFeedToFolderOperation(payload, dataStore: dataStore)

        case .createFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.CreateFolderPayload.self, from: operation.payload)
            try await self.processCreateFolderOperation(payload, dataStore: dataStore)

        case .deleteFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.DeleteFolderPayload.self, from: operation.payload)
            try await self.processDeleteFolderOperation(payload, dataStore: dataStore)

        case .renameFolder:
            let payload = try decoder.decode(PendingCloudKitOperation.RenameFolderPayload.self, from: operation.payload)
            try await self.processRenameFolderOperation(payload, dataStore: dataStore)
        }
    }

    // MARK: - Individual Operation Processors

    private func processCreateFeedOperation(
        _ payload: PendingCloudKitOperation.CreateFeedPayload,
        dataStore: DataStore
    ) async throws {
        // Find the container
        let container: Container
        if payload.containerExternalID == dataStore.externalID || payload.containerExternalID.hasPrefix("local-") {
            container = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
            container = folder
        } else {
            DZLog("iCloud: Cannot find container for createFeed operation")
            return
        }

        let externalID = try await feedsZone.createFeed(
            url: payload.url,
            name: payload.name,
            editedName: payload.editedName,
            homePageURL: payload.homePageURL,
            container: container
        )

        // Update the local feed with the real external ID
        if let feed = dataStore.existingFeed(withExternalID: payload.localFeedID) {
            feed.externalID = externalID
            self.sendNewArticlesToTheCloud(dataStore, feed)
        }
    }

    private func processDeleteFeedOperation(
        _ payload: PendingCloudKitOperation.DeleteFeedPayload,
        dataStore: DataStore
    ) async throws {
        // Try to delete from CloudKit using the external ID
        // If the feed doesn't exist locally, we still try to delete from CloudKit
        if let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) {
            let container: Container = if payload.containerExternalID == dataStore.externalID {
                dataStore
            } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
                folder
            } else {
                dataStore
            }
            _ = try await self.feedsZone.removeFeed(feed, from: container)
        } else {
            // Feed already deleted locally, try to delete from CloudKit directly
            try await self.feedsZone.delete(externalID: payload.feedExternalID)
        }
    }

    private func processRenameFeedOperation(
        _ payload: PendingCloudKitOperation.RenameFeedPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }
        try await self.feedsZone.renameFeed(feed, editedName: payload.editedName)
    }

    private func processMoveFeedOperation(
        _ payload: PendingCloudKitOperation.MoveFeedPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }

        let sourceContainer: Container
        if payload.fromContainerExternalID == dataStore.externalID {
            sourceContainer = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.fromContainerExternalID) {
            sourceContainer = folder
        } else {
            return
        }

        let destContainer: Container
        if payload.toContainerExternalID == dataStore.externalID {
            destContainer = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.toContainerExternalID) {
            destContainer = folder
        } else {
            return
        }

        try await self.feedsZone.moveFeed(feed, from: sourceContainer, to: destContainer)
    }

    private func processAddFeedToFolderOperation(
        _ payload: PendingCloudKitOperation.AddFeedToFolderPayload,
        dataStore: DataStore
    ) async throws {
        guard let feed = dataStore.existingFeed(withExternalID: payload.feedExternalID) else {
            return
        }

        let container: Container
        if payload.containerExternalID == dataStore.externalID {
            container = dataStore
        } else if let folder = dataStore.existingFolder(withExternalID: payload.containerExternalID) {
            container = folder
        } else {
            return
        }

        try await self.feedsZone.addFeed(feed, to: container)
    }

    private func processCreateFolderOperation(
        _ payload: PendingCloudKitOperation.CreateFolderPayload,
        dataStore: DataStore
    ) async throws {
        let externalID = try await feedsZone.createFolder(name: payload.name)

        // Update the local folder with the real external ID
        if let folder = dataStore.existingFolder(withExternalID: payload.localFolderID) {
            folder.externalID = externalID
        }
    }

    private func processDeleteFolderOperation(
        _ payload: PendingCloudKitOperation.DeleteFolderPayload,
        dataStore: DataStore
    ) async throws {
        if let folder = dataStore.existingFolder(withExternalID: payload.folderExternalID) {
            try await self.feedsZone.removeFolder(folder)
        } else {
            // Folder already deleted locally, try to delete from CloudKit directly
            try await self.feedsZone.delete(externalID: payload.folderExternalID)
        }
    }

    private func processRenameFolderOperation(
        _ payload: PendingCloudKitOperation.RenameFolderPayload,
        dataStore: DataStore
    ) async throws {
        guard let folder = dataStore.existingFolder(withExternalID: payload.folderExternalID) else {
            return
        }
        try await self.feedsZone.renameFolder(folder, to: payload.name)
    }
}
