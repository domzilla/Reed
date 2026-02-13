//
//  PendingCloudKitOperationTable.swift
//  Reed
//
//  Created by Claude on 1/11/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct PendingCloudKitOperationTable: Sendable {
    static let name = "pendingCloudKitOperations"

    nonisolated static func selectForProcessing(limit: Int?, database: FMDatabase) -> [PendingCloudKitOperation]? {
        database.beginTransaction()

        let updateSQL = "update \(name) set selected = true"
        guard database.executeUpdate(updateSQL, withArgumentsIn: nil) else {
            database.rollback()
            return nil
        }

        let selectSQL: String = {
            var sql = "select * from \(name) where selected == true order by createdAt ASC"
            if let limit {
                sql = "\(sql) limit \(limit)"
            }
            return sql
        }()

        guard let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) else {
            database.rollback()
            return nil
        }

        let operations = resultSet.compactMap { operationWithRow($0) }

        database.commit()

        return operations
    }

    nonisolated static func selectPendingCount(database: FMDatabase) -> Int? {
        let sql = "select count(*) from \(name)"
        guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
            return nil
        }

        let count = resultSet.intWithCountResult()
        return count
    }

    nonisolated static func resetAllSelectedForProcessing(database: FMDatabase) {
        let updateSQL = "update \(name) set selected = false"
        database.executeUpdateInTransaction(updateSQL)
    }

    nonisolated static func resetSelectedForProcessing(_ ids: Set<String>, database: FMDatabase) {
        guard !ids.isEmpty else {
            return
        }

        let parameters = ids.map { $0 as AnyObject }
        let placeholders = NSString.rd_SQLValueList(withPlaceholders: UInt(ids.count))!
        let updateSQL = "update \(name) set selected = false where id in \(placeholders)"
        database.executeUpdateInTransaction(updateSQL, withArgumentsIn: parameters)
    }

    nonisolated static func deleteSelectedForProcessing(_ ids: Set<String>, database: FMDatabase) {
        guard !ids.isEmpty else {
            return
        }

        let parameters = ids.map { $0 as AnyObject }
        let placeholders = NSString.rd_SQLValueList(withPlaceholders: UInt(ids.count))!
        let deleteSQL = "delete from \(name) where selected = true and id in \(placeholders)"
        database.executeUpdateInTransaction(deleteSQL, withArgumentsIn: parameters)
    }

    nonisolated static func insertOperation(_ operation: PendingCloudKitOperation, database: FMDatabase) {
        database.beginTransaction()

        let dict = operation.databaseDictionary()
        database.insertRows([dict], insertType: .orReplace, tableName: self.name)

        database.commit()
    }

    nonisolated static func insertOperations(_ operations: [PendingCloudKitOperation], database: FMDatabase) {
        guard !operations.isEmpty else { return }

        database.beginTransaction()

        let dicts = operations.map { $0.databaseDictionary() }
        database.insertRows(dicts, insertType: .orReplace, tableName: self.name)

        database.commit()
    }

    nonisolated static func deleteOperation(_ id: String, database: FMDatabase) {
        let deleteSQL = "delete from \(name) where id = ?"
        database.executeUpdateInTransaction(deleteSQL, withArgumentsIn: [id as AnyObject])
    }

    nonisolated static func deleteAllOperations(database: FMDatabase) {
        let deleteSQL = "delete from \(name)"
        database.executeUpdateInTransaction(deleteSQL)
    }
}

extension PendingCloudKitOperationTable {
    fileprivate nonisolated static func operationWithRow(_ row: FMResultSet) -> PendingCloudKitOperation? {
        guard
            let id = row.string(forColumn: PendingOperationKey.id),
            let rawType = row.string(forColumn: PendingOperationKey.operationType),
            let operationType = PendingCloudKitOperation.OperationType(rawValue: rawType),
            let payload = row.data(forColumn: PendingOperationKey.payload) else
        {
            return nil
        }

        let createdAt = Date(timeIntervalSince1970: row.double(forColumn: PendingOperationKey.createdAt))
        let selected = row.bool(forColumn: PendingOperationKey.selected)

        return PendingCloudKitOperation(
            id: id,
            operationType: operationType,
            payload: payload,
            createdAt: createdAt,
            selected: selected
        )
    }
}
