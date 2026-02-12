//
//  DatabaseObjectCache.swift
//  RDDatabase
//
//  Created by Brent Simmons on 9/12/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

final class DatabaseObjectCache: Sendable {
    private let state = Mutex([String: DatabaseObject]())

    init() {
        //
    }

    func add(_ databaseObjects: [DatabaseObject]) {
        self.state.withLock { d in
            for databaseObject in databaseObjects {
                d[databaseObject.databaseID] = databaseObject
            }
        }
    }

    subscript(_ databaseID: String) -> DatabaseObject? {
        get {
            self.state.withLock { $0[databaseID] }
        }
        set {
            self.state.withLock { $0[databaseID] = newValue }
        }
    }
}
