//
//  CloudKitSyncProvider+FolderOperations.swift
//  Reed
//
//  Extracted from CloudKitSyncProvider.swift
//

import DZFoundation
import Foundation

// MARK: - Folder Operations

extension CloudKitSyncProvider {
    func createFolder(for dataStore: DataStore, name: String) async throws -> Folder {
        // Create folder locally first
        guard let folder = dataStore.ensureFolder(with: name) else {
            throw DataStoreError.invalidParameter
        }

        // Assign temporary local ID if iCloud is not available
        let localExternalID = self.generateLocalExternalID()
        folder.externalID = localExternalID

        // Try to sync to CloudKit
        if iCloudAccountMonitor.shared.isAvailable {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                let externalID = try await feedsZone.createFolder(name: name)
                folder.externalID = externalID
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    // Queue the operation for later
                    queueCreateFolderOperation(name: name, localFolderID: localExternalID)
                    DZLog("iCloud: Queued createFolder operation for later sync")
                } else {
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else {
            // Queue the operation for when iCloud becomes available
            queueCreateFolderOperation(name: name, localFolderID: localExternalID)
            DZLog("iCloud: Created folder locally, queued for sync when iCloud available")
        }

        return folder
    }

    func renameFolder(for dataStore: DataStore, with folder: Folder, to name: String) async throws {
        // Rename locally first
        let oldName = folder.name
        folder.name = name

        // Try to sync to CloudKit
        guard let externalID = folder.externalID else {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable, !externalID.hasPrefix("local-") {
            self.syncProgress.addTask()
            defer { syncProgress.completeTask() }

            do {
                try await self.feedsZone.renameFolder(folder, to: name)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueRenameFolderOperation(folderExternalID: externalID, name: name)
                    DZLog("iCloud: Queued renameFolder operation for later sync")
                } else {
                    // Revert local change on non-recoverable error
                    folder.name = oldName
                    processSyncError(dataStore, error)
                    throw error
                }
            }
        } else if !externalID.hasPrefix("local-") {
            // Queue if iCloud not available but we have a real external ID
            queueRenameFolderOperation(folderExternalID: externalID, name: name)
            DZLog("iCloud: Renamed folder locally, queued for sync when iCloud available")
        }
        // If the folder has a local-only ID, the rename will be synced when the folder is created
    }

    func removeFolder(for dataStore: DataStore, with folder: Folder) async throws {
        self.syncProgress.addTask()

        let feedExternalIDs: [String]
        do {
            feedExternalIDs = try await self.feedsZone.findFeedExternalIDs(for: folder)
            self.syncProgress.completeTask()
        } catch {
            self.syncProgress.completeTask()
            self.syncProgress.completeTask()
            processSyncError(dataStore, error)
            throw error
        }

        let feeds = feedExternalIDs.compactMap { dataStore.existingFeed(withExternalID: $0) }
        var errorOccurred = false

        await withTaskGroup(of: Result<Void, Error>.self) { group in
            for feed in feeds {
                group.addTask {
                    do {
                        try await self.removeFeedFromCloud(for: dataStore, with: feed, from: folder)
                        return .success(())
                    } catch {
                        DZLog("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                if case .failure = result {
                    errorOccurred = true
                }
            }
        }

        guard !errorOccurred else {
            self.syncProgress.completeTask()
            throw CloudKitSyncProviderError.unknown
        }

        do {
            try await self.feedsZone.removeFolder(folder)
            self.syncProgress.completeTask()
            dataStore.removeFolderFromTree(folder)
        } catch {
            self.syncProgress.completeTask()
            throw error
        }
    }

    func restoreFolder(for dataStore: DataStore, folder: Folder) async throws {
        guard let name = folder.name else {
            throw DataStoreError.invalidParameter
        }

        let feedsToRestore = folder.topLevelFeeds
        self.syncProgress.addTasks(1 + feedsToRestore.count)

        do {
            let externalID = try await feedsZone.createFolder(name: name)
            self.syncProgress.completeTask()

            folder.externalID = externalID
            dataStore.addFolderToTree(folder)

            await withTaskGroup(of: Void.self) { group in
                for feed in feedsToRestore {
                    folder.topLevelFeeds.remove(feed)

                    group.addTask {
                        do {
                            try await self.restoreFeed(for: dataStore, feed: feed, container: folder)
                            self.syncProgress.completeTask()
                        } catch {
                            DZLog("CloudKit: Restore folder feed error: \(error.localizedDescription)")
                            self.syncProgress.completeTask()
                        }
                    }
                }
            }

            dataStore.addFolderToTree(folder)
        } catch {
            self.syncProgress.completeTask()
            processSyncError(dataStore, error)
            throw error
        }
    }
}
