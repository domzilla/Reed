//
//  Cache.swift
//
//
//  Created by Brent Simmons on 10/12/24.
//

import Foundation
import Synchronization

protocol CacheRecord: Sendable {
    var dateCreated: Date { get }
}

final class Cache<T: CacheRecord>: Sendable {
    let timeToLive: TimeInterval
    let timeBetweenCleanups: TimeInterval

    private struct State: Sendable {
        var lastCleanupDate = Date()
        var cache = [String: T]()
    }

    private let stateLock = Mutex(State())

    init(timeToLive: TimeInterval, timeBetweenCleanups: TimeInterval) {
        self.timeToLive = timeToLive
        self.timeBetweenCleanups = timeBetweenCleanups
    }

    subscript(_ key: String) -> T? {
        get {
            self.stateLock.withLock { state in
                cleanupIfNeeded(&state)

                guard let value = state.cache[key] else {
                    return nil
                }
                if value.dateCreated.timeIntervalSinceNow < -self.timeToLive {
                    state.cache[key] = nil
                    return nil
                }

                return value
            }
        }
        set {
            self.stateLock.withLock { state in
                state.cache[key] = newValue
            }
        }
    }

    func cleanup() {
        self.stateLock.withLock { state in
            cleanupIfNeeded(&state)
        }
    }
}

extension Cache {
    private func cleanupIfNeeded(_ state: inout State) {
        let currentDate = Date()
        guard state.lastCleanupDate.timeIntervalSince(currentDate) < -self.timeBetweenCleanups else {
            return
        }

        var keysToDelete = [String]()
        for (key, value) in state.cache {
            if value.dateCreated.timeIntervalSince(currentDate) < -self.timeToLive {
                keysToDelete.append(key)
            }
        }

        for key in keysToDelete {
            state.cache[key] = nil
        }

        state.lastCleanupDate = Date()
    }
}
