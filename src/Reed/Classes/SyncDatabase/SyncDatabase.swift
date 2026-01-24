//
//  SyncDatabase.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

public actor SyncDatabase {
    private var database: FMDatabase?
    private let databasePath: String

    public init(databasePath: String) {
        let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
        database.runCreateStatements(Self.tableCreationStatements)
        database.vacuumIfNeeded(daysBetweenVacuums: 11, filepath: databasePath)

        self.database = database
        self.databasePath = databasePath
    }

    // MARK: - API

    public func insertStatuses(_ statuses: Set<SyncStatus>) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        SyncStatusTable.insertStatuses(statuses, database: database)
    }

    public func selectForProcessing(limit: Int? = nil) throws -> Set<SyncStatus>? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return SyncStatusTable.selectForProcessing(limit: limit, database: database)
    }

    public func selectPendingCount() throws -> Int? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return SyncStatusTable.selectPendingCount(database: database)
    }

    public func selectPendingReadStatusArticleIDs() throws -> Set<String>? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return SyncStatusTable.selectPendingReadStatusArticleIDs(database: database)
    }

    public func selectPendingStarredStatusArticleIDs() throws -> Set<String>? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return SyncStatusTable.selectPendingStarredStatusArticleIDs(database: database)
    }

    public nonisolated func resetAllSelectedForProcessing() {
        Task {
            try? await _resetAllSelectedForProcessing()
        }
    }

    public func resetSelectedForProcessing(_ articleIDs: Set<String>) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        SyncStatusTable.resetSelectedForProcessing(articleIDs, database: database)
    }

    public func deleteSelectedForProcessing(_ articleIDs: Set<String>) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        SyncStatusTable.deleteSelectedForProcessing(articleIDs, database: database)
    }

    // MARK: - Pending CloudKit Operations

    public func insertPendingOperation(_ operation: PendingCloudKitOperation) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.insertOperation(operation, database: database)
    }

    public func insertPendingOperations(_ operations: [PendingCloudKitOperation]) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.insertOperations(operations, database: database)
    }

    public func selectPendingOperationsForProcessing(limit: Int? = nil) throws -> [PendingCloudKitOperation]? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return PendingCloudKitOperationTable.selectForProcessing(limit: limit, database: database)
    }

    public func selectPendingOperationsCount() throws -> Int? {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        return PendingCloudKitOperationTable.selectPendingCount(database: database)
    }

    public func resetPendingOperationsSelectedForProcessing(_ ids: Set<String>) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.resetSelectedForProcessing(ids, database: database)
    }

    public func deletePendingOperationsSelectedForProcessing(_ ids: Set<String>) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.deleteSelectedForProcessing(ids, database: database)
    }

    public func deletePendingOperation(_ id: String) throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.deleteOperation(id, database: database)
    }

    public nonisolated func resetAllPendingOperationsSelectedForProcessing() {
        Task {
            try? await _resetAllPendingOperationsSelectedForProcessing()
        }
    }

    // MARK: - Suspend and Resume

    public nonisolated func suspend() {
        Task {
            await _suspend()
        }
    }

    public nonisolated func resume() {
        Task {
            await _resume()
        }
    }
}

// MARK: - Private

extension SyncDatabase {
    fileprivate static let tableCreationStatements = """
    CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
    CREATE TABLE if not EXISTS pendingCloudKitOperations (id TEXT PRIMARY KEY NOT NULL, operationType TEXT NOT NULL, payload BLOB NOT NULL, createdAt REAL NOT NULL, selected BOOL NOT NULL DEFAULT 0);
    """

    private func _resetAllSelectedForProcessing() throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        SyncStatusTable.resetAllSelectedForProcessing(database: database)
    }

    private func _resetAllPendingOperationsSelectedForProcessing() throws {
        guard let database else {
            throw DatabaseError.isSuspended
        }
        PendingCloudKitOperationTable.resetAllSelectedForProcessing(database: database)
    }

    private func _suspend() {
        self.database?.close()
        self.database = nil
    }

    private func _resume() {
        if self.database == nil {
            self.database = FMDatabase.openAndSetUpDatabase(path: self.databasePath)
        }
    }
}
