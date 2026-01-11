//
//  SidebarItemIdentifier.swift
//  DataStore
//
//  Created by Maurice Parker on 11/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor public protocol SidebarItemIdentifiable {
	var sidebarItemID: SidebarItemIdentifier? { get }
}

public enum SidebarItemIdentifier: CustomStringConvertible, Hashable, Equatable, Sendable {
	case smartFeed(String) // String is a unique identifier
	case script(String) // String is a unique identifier
	case feed(String, String) // dataStoreID, feedID
	case folder(String, String) // dataStoreID, folderName

	private struct TypeName {
		static let smartFeed = "smartFeed"
		static let script = "script"
		static let feed = "feed"
		static let folder = "folder"
	}

	private struct Key {
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
			return TypeName.smartFeed
		case .script:
			return TypeName.script
		case .feed:
			return TypeName.feed
		case .folder:
			return TypeName.folder
		}
	}

	public var description: String {
		switch self {
		case .smartFeed(let id):
			return "(typeName): \(id)"
		case .script(let id):
			return "(typeName): \(id)"
		case .feed(let dataStoreID, let feedID):
			return "(typeName): \(dataStoreID)_\(feedID)"
		case .folder(let dataStoreID, let folderName):
			return "(typeName): \(dataStoreID)_\(folderName)"
		}
	}

	public var userInfo: [String: String] {
		var d = [Key.typeName: typeName]

		switch self {
		case .smartFeed(let id):
			d[Key.id] = id
		case .script(let id):
			d[Key.id] = id
		case .feed(let dataStoreID, let feedID):
			d[Key.dataStoreID] = dataStoreID
			d[Key.feedID] = feedID
		case .folder(let dataStoreID, let folderName):
			d[Key.dataStoreID] = dataStoreID
			d[Key.folderName] = folderName
		}

		return d
	}

	public init?(userInfo: [String: String]) {
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
			guard let dataStoreID = userInfo[Key.dataStoreID], let feedID = userInfo[Key.feedID] ?? userInfo[Key.oldFeedIDKey] else {
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
