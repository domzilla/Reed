//
//  ContainerIdentifier.swift
//  DataStore
//
//  Created by Maurice Parker on 11/24/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
public protocol ContainerIdentifiable {
    var containerID: ContainerIdentifier? { get }
}

public enum ContainerIdentifier: Hashable, Equatable, Sendable {
    case smartFeedController
    case dataStore(String) // dataStoreID
    case folder(String, String) // dataStoreID, folderName

    public var userInfo: [AnyHashable: AnyHashable] {
        switch self {
        case .smartFeedController:
            [
                "type": "smartFeedController",
            ]
        case let .dataStore(dataStoreID):
            [
                "type": "dataStore",
                "dataStoreID": dataStoreID,
            ]
        case let .folder(dataStoreID, folderName):
            [
                "type": "folder",
                "dataStoreID": dataStoreID,
                "folderName": folderName,
            ]
        }
    }

    public init?(userInfo: [AnyHashable: AnyHashable]) {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "smartFeedController":
            self = ContainerIdentifier.smartFeedController
        case "dataStore", "account": // "account" for backward compatibility
            guard let dataStoreID = userInfo["dataStoreID"] as? String ?? userInfo["accountID"] as? String else { return nil }
            self = ContainerIdentifier.dataStore(dataStoreID)
        case "folder":
            guard
                let dataStoreID = userInfo["dataStoreID"] as? String ?? userInfo["accountID"] as? String,
                let folderName = userInfo["folderName"] as? String else { return nil }
            self = ContainerIdentifier.folder(dataStoreID, folderName)
        default:
            return nil
        }
    }
}

extension ContainerIdentifier: Encodable {
    enum CodingKeys: CodingKey {
        case type
        case dataStoreID
        case folderName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .smartFeedController:
            try container.encode("smartFeedController", forKey: .type)
        case let .dataStore(dataStoreID):
            try container.encode("dataStore", forKey: .type)
            try container.encode(dataStoreID, forKey: .dataStoreID)
        case let .folder(dataStoreID, folderName):
            try container.encode("folder", forKey: .type)
            try container.encode(dataStoreID, forKey: .dataStoreID)
            try container.encode(folderName, forKey: .folderName)
        }
    }
}

extension ContainerIdentifier: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "smartFeedController":
            self = .smartFeedController
        case "dataStore", "account": // "account" for backward compatibility
            // Try new key first, fall back to old key for backward compatibility
            let dataStoreID = try? container.decode(String.self, forKey: .dataStoreID)
            if let dataStoreID {
                self = .dataStore(dataStoreID)
            } else {
                // Legacy support: try to decode with old CodingKeys
                let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
                let accountID = try legacyContainer.decode(String.self, forKey: .accountID)
                self = .dataStore(accountID)
            }
        default:
            let dataStoreID = try? container.decode(String.self, forKey: .dataStoreID)
            let folderName = try container.decode(String.self, forKey: .folderName)
            if let dataStoreID {
                self = .folder(dataStoreID, folderName)
            } else {
                let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
                let accountID = try legacyContainer.decode(String.self, forKey: .accountID)
                self = .folder(accountID, folderName)
            }
        }
    }

    private enum LegacyCodingKeys: CodingKey {
        case accountID
    }
}
