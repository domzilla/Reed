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
        // Capture references before local removal
        let folderExternalID = folder.externalID
        let feeds = Array(folder.topLevelFeeds)

        // Remove locally first — clear feed metadata and remove folder from tree
        for feed in feeds {
            dataStore.clearFeedMetadata(feed)
        }
        dataStore.removeFolderFromTree(folder)

        // Try to sync to CloudKit (only if we have a real external ID)
        guard let folderExtID = folderExternalID, !folderExtID.hasPrefix("local-") else {
            return
        }

        if iCloudAccountMonitor.shared.isAvailable {
            // Remove feeds from CloudKit (best-effort, each handles its own progress)
            for feed in feeds {
                do {
                    try await self.removeFeedFromCloud(for: dataStore, with: feed, from: folder)
                } catch {
                    DZLog("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
                }
            }

            // Remove the folder from CloudKit
            do {
                try await self.feedsZone.removeFolder(folder)
            } catch {
                if iCloudAccountMonitor.isRecoverableError(error) {
                    queueDeleteFolderOperation(folderExternalID: folderExtID)
                    DZLog("iCloud: Queued deleteFolder operation for later sync")
                } else {
                    DZLog(
                        "iCloud: Remove folder CloudKit error (local removal succeeded): \(error.localizedDescription)"
                    )
                }
            }
        } else {
            // Queue individual feed deletions and folder deletion for later sync
            for feed in feeds {
                if let feedExtID = feed.externalID, !feedExtID.hasPrefix("local-") {
                    queueDeleteFeedOperation(feedExternalID: feedExtID, containerExternalID: folderExtID)
                }
            }
            queueDeleteFolderOperation(folderExternalID: folderExtID)
            DZLog("iCloud: Removed folder locally, queued for sync when iCloud available")
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
