//
//  DatabaseQueue.swift
//  RSDatabase
//
//  Created by Brent Simmons on 11/13/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import DZFoundation
import Foundation
import SQLite3
import Synchronization

/// Manage a serial queue and a SQLite database.
///
/// On iOS, the queue can be suspended
/// in order to support background refreshing.
final class DatabaseQueue: Sendable {
    private struct State {
        var isCallingDatabase = false
        var isSuspended = false
        let database: FMDatabase

        init(_ database: FMDatabase) {
            self.database = database
        }
    }

    private let state: Mutex<State>
    private let databasePath: String
    private let serialDispatchQueue: DispatchQueue

    init(databasePath: String) {
        DZLog("DatabaseQueue: creating with database path \(databasePath)")

        self.serialDispatchQueue = DispatchQueue(label: "DatabaseQueue (Serial) - \(databasePath)")

        self.databasePath = databasePath
        let database = FMDatabase(path: databasePath)!
        self.state = Mutex(State(database))

        self.state.withLock { openDatabase($0.database) }
    }

    // MARK: - Suspend and Resume

    /// Close the SQLite database and don’t allow database calls until resumed.
    /// This is for iOS, where we need to close the SQLite database in some conditions.
    ///
    /// After calling suspend, if you call into the database before calling resume,
    /// your code will not run, and runInDatabaseSync and runInTransactionSync will
    /// both throw DatabaseQueueError.isSuspended.
    ///
    /// On Mac, suspend() and resume() are no-ops, since there isn’t a need for them.
    func suspend() {
        #if os(iOS)
        DZLog("DatabaseQueue: suspending")
        self.state.withLock { state in
            guard !state.isSuspended else {
                assertionFailure("DatabaseQueue: suspend called when already suspended")
                return
            }

            state.isSuspended = true
            self.serialDispatchQueue.suspend()
            state.database.close()
        }
        #endif
    }

    /// Open the SQLite database. Allow database calls again.
    /// iOS only — does nothing on macOS.
    func resume() {
        #if os(iOS)
        DZLog("DatabaseQueue: resuming")
        self.state.withLock { state in
            guard state.isSuspended else {
                assertionFailure("DatabaseQueue: resume called when already resumed")
                return
            }

            state.isSuspended = false
            openDatabase(state.database)
            self.serialDispatchQueue.resume()
        }
        #endif
    }

    // MARK: - Make Database Calls

    /// Run a DatabaseBlock synchronously. This call will block the main thread
    /// potentially for a while, depending on how long it takes to execute
    /// the DatabaseBlock *and* depending on how many other calls have been
    /// scheduled on the queue. Use sparingly — prefer async versions.
    func runInDatabaseSync(_ databaseBlock: DatabaseBlock) {
        self.serialDispatchQueue.sync {
            self.state.withLock { state in
                self._runInDatabase(&state, databaseBlock, false)
            }
        }
    }

    /// Run a DatabaseBlock asynchronously.
    func runInDatabase(_ databaseBlock: @escaping DatabaseBlock) {
        self.serialDispatchQueue.async {
            self.state.withLock { state in
                self._runInDatabase(&state, databaseBlock, false)
            }
        }
    }

    /// Run a DatabaseBlock wrapped in a transaction synchronously.
    /// Transactions help performance significantly when updating the database.
    /// Nevertheless, it’s best to avoid this because it will block the main thread —
    /// prefer the async `runInTransaction` instead.
    func runInTransactionSync(_ databaseBlock: @escaping DatabaseBlock) {
        self.serialDispatchQueue.sync {
            self.state.withLock { state in
                self._runInDatabase(&state, databaseBlock, true)
            }
        }
    }

    /// Run a DatabaseBlock wrapped in a transaction asynchronously.
    /// Transactions help performance significantly when updating the database.
    func runInTransaction(_ databaseBlock: @escaping DatabaseBlock) {
        self.serialDispatchQueue.async {
            self.state.withLock { state in
                self._runInDatabase(&state, databaseBlock, true)
            }
        }
    }

    /// Run all the lines that start with "create".
    /// Use this to create tables, indexes, etc.
    func runCreateStatements(_ statements: String) throws {
        nonisolated(unsafe) var error: DatabaseError? = nil

        self.runInDatabaseSync { result in
            DZLog("DatabaseQueue: runCreateStatements")

            switch result {
            case let .success(database):
                statements.enumerateLines { line, stop in
                    if line.lowercased().hasPrefix("create") {
                        database.executeStatements(line)
                    }
                    stop = false
                }
            case let .failure(databaseError):
                error = databaseError
            }
        }

        if let error {
            throw (error)
        }
    }

    /// Compact the database. This should be done from time to time —
    /// weekly-ish? — to keep up the performance level of a database.
    /// Generally a thing to do at startup, if it’s been a while
    /// since the last vacuum() call. You almost certainly want to call
    /// vacuumIfNeeded instead.
    func vacuum() {
        self.runInDatabase { result in
            DZLog("DatabaseQueue: vacuum")
            guard let database = try? result.get() else {
                return
            }
            database.executeStatements("vacuum;")
        }
    }

    /// Vacuum the database if it’s been more than `daysBetweenVacuums` since the last vacuum.
    /// Normally you would call this right after initing a DatabaseQueue.
    ///
    /// - Returns: true if database will be vacuumed.
    @discardableResult
    func vacuumIfNeeded(daysBetweenVacuums: Int) -> Bool {
        let defaultsKey = "DatabaseQueue-LastVacuumDate-\(databasePath)"
        let minimumVacuumInterval = TimeInterval(daysBetweenVacuums * (60 * 60 * 24)) // Doesn’t have to be precise
        let now = Date()
        let cutoffDate = now - minimumVacuumInterval
        if let lastVacuumDate = UserDefaults.standard.object(forKey: defaultsKey) as? Date {
            if lastVacuumDate < cutoffDate {
                self.vacuum()
                UserDefaults.standard.set(now, forKey: defaultsKey)
                return true
            }
            return false
        }

        // Never vacuumed — almost certainly a new database.
        // Just set the LastVacuumDate pref to now and skip vacuuming.
        UserDefaults.standard.set(now, forKey: defaultsKey)
        return false
    }
}

extension DatabaseQueue {
    private func _runInDatabase(_ state: inout State, _ databaseBlock: DatabaseBlock, _ useTransaction: Bool) {
        precondition(!state.isCallingDatabase)

        state.isCallingDatabase = true
        defer {
            state.isCallingDatabase = false
        }

        autoreleasepool {
            if state.isSuspended {
                databaseBlock(.failure(.isSuspended))
            } else {
                if useTransaction {
                    state.database.beginTransaction()
                }
                databaseBlock(.success(state.database))
                if useTransaction {
                    state.database.commit()
                }
            }
        }
    }

    private func openDatabase(_ database: FMDatabase) {
        database.open()
        database.executeStatements("PRAGMA synchronous = 1;")
        database.setShouldCacheStatements(true)
    }
}
