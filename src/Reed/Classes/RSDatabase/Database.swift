//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation

enum DatabaseError: Error, LocalizedError, Sendable {
    case isSuspended // On iOS, to support background refreshing, a database may be suspended.

    var errorDescription: String? {
        switch self {
        case .isSuspended:
            NSLocalizedString("Database is suspended", comment: "Database suspended error")
        }
    }
}

/// Result type that provides an FMDatabase or a DatabaseError.
typealias DatabaseResult = Result<FMDatabase, DatabaseError>

/// Block that executes database code or handles DatabaseQueueError.
typealias DatabaseBlock = @Sendable (DatabaseResult) -> Void

/// Completion block that provides an optional DatabaseError.
typealias DatabaseCompletionBlock = @Sendable (DatabaseError?) -> Void

/// Result type for fetching an Int or getting a DatabaseError.
typealias DatabaseIntResult = Result<Int, DatabaseError>

/// Completion block for DatabaseIntResult.
typealias DatabaseIntCompletionBlock = (DatabaseIntResult) -> Void

// MARK: - Extensions

extension DatabaseResult {
    /// Convenience for getting the database from a DatabaseResult.
    var database: FMDatabase? {
        switch self {
        case let .success(database):
            database
        case .failure:
            nil
        }
    }

    /// Convenience for getting the error from a DatabaseResult.
    var error: DatabaseError? {
        switch self {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
