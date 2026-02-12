//
//  SharedTypes.swift
//  Reed
//
//  Types shared between the main app and the share extension.
//  These are duplicated here to avoid complex build configuration.
//

import Foundation

// MARK: - DataStoreType (formerly AccountType)

public nonisolated enum DataStoreType: Int, Codable, Sendable {
    // Raw values should not change since they're stored on disk.
    case onMyMac = 1
    case cloudKit = 2

    public var isDeveloperRestricted: Bool {
        self == .cloudKit
    }
}

// MARK: - ContainerIdentifier

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
        case "dataStore", "account":
            guard let dataStoreID = (userInfo["dataStoreID"] ?? userInfo["accountID"]) as? String else { return nil }
            self = ContainerIdentifier.dataStore(dataStoreID)
        case "folder":
            guard
                let dataStoreID = (userInfo["dataStoreID"] ?? userInfo["accountID"]) as? String,
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
    private enum DecodingKeys: String, CodingKey {
        case type
        case dataStoreID
        case accountID // backward compat
        case folderName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "smartFeedController":
            self = .smartFeedController
        case "dataStore", "account":
            let dataStoreID = try (container.decodeIfPresent(String.self, forKey: .dataStoreID)
                ?? container.decode(String.self, forKey: .accountID))
            self = .dataStore(dataStoreID)
        default:
            let dataStoreID = try (container.decodeIfPresent(String.self, forKey: .dataStoreID)
                ?? container.decode(String.self, forKey: .accountID))
            let folderName = try container.decode(String.self, forKey: .folderName)
            self = .folder(dataStoreID, folderName)
        }
    }
}
