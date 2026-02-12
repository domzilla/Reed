//
//  DatabaseObject.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

typealias DatabaseDictionary = [String: Any]

protocol DatabaseObject: Sendable {
    var databaseID: String { get }

    func databaseDictionary() -> DatabaseDictionary?

    func relatedObjectsWithName(_ name: String) -> [DatabaseObject]?
}

extension DatabaseObject {
    func relatedObjectsWithName(_: String) -> [DatabaseObject]? {
        nil
    }
}

extension [DatabaseObject] {
    func dictionary() -> [String: DatabaseObject] {
        var d = [String: DatabaseObject]()
        for object in self {
            d[object.databaseID] = object
        }
        return d
    }

    func databaseIDs() -> Set<String> {
        Set(self.map(\.databaseID))
    }

    func includesObjectWithDatabaseID(_ databaseID: String) -> Bool {
        for object in self {
            if object.databaseID == databaseID {
                return true
            }
        }
        return false
    }

    func databaseDictionaries() -> [DatabaseDictionary]? {
        let dictionaries = self.compactMap { $0.databaseDictionary() }
        return dictionaries.isEmpty ? nil : dictionaries
    }
}
