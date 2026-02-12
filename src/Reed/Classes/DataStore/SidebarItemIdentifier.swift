//
//  SidebarItemIdentifier.swift
//  DataStore
//
//  Created by Maurice Parker on 11/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
protocol SidebarItemIdentifiable {
    var sidebarItemID: SidebarItemIdentifier? { get }
}

enum SidebarItemIdentifier: CustomStringConvertible, Hashable, Equatable, Sendable {
    case smartFeed(String) // String is a unique identifier
    case script(String) // String is a unique identifier
    case feed(String, String) // dataStoreID, feedID
    case folder(String, String) // dataStoreID, folderName

    private enum TypeName {
        static let smartFeed = "smartFeed"
        static let script = "script"
        static let feed = "feed"
        static let folder = "folder"
    }

    private enum Key {
        static let typeName = "type"
        static let id = "id"
        static let dataStoreID = "accountID" // kept as "accountID" for backward compatibility
        static let feedID = "feedID"
        static let oldFeedIDKey = "webFeedID"
        static let folderName = "folderName"
    }

    private var typeName: String {
        switch self {
        case .smartFeed:
            TypeName.smartFeed
        case .script:
            TypeName.script
        case .feed:
            TypeName.feed
        case .folder:
            TypeName.folder
        }
    }

    var description: String {
        switch self {
        case let .smartFeed(id):
            "(typeName): \(id)"
        case let .script(id):
            "(typeName): \(id)"
        case let .feed(dataStoreID, feedID):
            "(typeName): \(dataStoreID)_\(feedID)"
        case let .folder(dataStoreID, folderName):
            "(typeName): \(dataStoreID)_\(folderName)"
        }
    }

    var userInfo: [String: String] {
        var d = [Key.typeName: self.typeName]

        switch self {
        case let .smartFeed(id):
            d[Key.id] = id
        case let .script(id):
            d[Key.id] = id
        case let .feed(dataStoreID, feedID):
            d[Key.dataStoreID] = dataStoreID
            d[Key.feedID] = feedID
        case let .folder(dataStoreID, folderName):
            d[Key.dataStoreID] = dataStoreID
            d[Key.folderName] = folderName
        }

        return d
    }

    init?(userInfo: [String: String]) {
        guard let type = userInfo[Key.typeName] else {
            return nil
        }

        switch type {
        case TypeName.smartFeed:
            guard let id = userInfo[Key.id] else {
                return nil
            }
            self = .smartFeed(id)
        case TypeName.script:
            guard let id = userInfo[Key.id] else {
                return nil
            }
            self = .script(id)
        case TypeName.feed:
            guard
                let dataStoreID = userInfo[Key.dataStoreID],
                let feedID = userInfo[Key.feedID] ?? userInfo[Key.oldFeedIDKey] else
            {
                return nil
            }
            self = .feed(dataStoreID, feedID)
        case TypeName.folder:
            guard let dataStoreID = userInfo[Key.dataStoreID], let folderName = userInfo[Key.folderName] else {
                return nil
            }
            self = .folder(dataStoreID, folderName)
        default:
            assertionFailure("Expected valid SidebarItemIdentifier.userInfo but got \(userInfo)")
            return nil
        }
    }
}
