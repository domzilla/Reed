//
//  ArticleStatus+Database.swift
//  Reed
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

extension ArticleStatus {
    convenience init(articleID: String, dateArrived: Date, row: FMResultSet) {
        let read = row.bool(forColumn: DatabaseKey.read)
        let starred = row.bool(forColumn: DatabaseKey.starred)

        self.init(articleID: articleID, read: read, starred: starred, dateArrived: dateArrived)
    }
}

extension ArticleStatus: DatabaseObject {
    nonisolated var databaseID: String {
        articleID
    }

    nonisolated func databaseDictionary() -> DatabaseDictionary? {
        [
            DatabaseKey.articleID: articleID,
            DatabaseKey.read: read,
            DatabaseKey.starred: starred,
            DatabaseKey.dateArrived: dateArrived,
        ]
    }
}
