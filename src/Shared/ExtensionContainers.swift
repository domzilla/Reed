//
//  ExtensionContainers.swift
//  Reed
//
//  Created by Maurice Parker on 2/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

protocol ExtensionContainer: Codable, Sendable {
    var name: String { get }
    var dataStoreID: String { get }
    var containerID: ContainerIdentifier? { get }
}

struct ExtensionContainers: Codable {
    enum CodingKeys: String, CodingKey {
        case dataStores = "accounts"
    }

    let dataStores: [ExtensionDataStore]

    var flattened: [ExtensionContainer] {
        self.dataStores.reduce([ExtensionContainer]()) { containers, dataStore in
            var result = containers
            result.append(dataStore)
            result.append(contentsOf: dataStore.folders)
            return result
        }
    }

    func findDataStore(forName name: String) -> ExtensionDataStore? {
        self.dataStores.first(where: { $0.name == name })
    }
}

struct ExtensionDataStore: ExtensionContainer {
    enum CodingKeys: String, CodingKey {
        case name
        case dataStoreID = "accountID"
        case disallowFeedInRootFolder
        case containerID
        case folders
    }

    let name: String
    let dataStoreID: String
    let disallowFeedInRootFolder: Bool
    let containerID: ContainerIdentifier?
    let folders: [ExtensionFolder]

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.dataStoreID = try container.decode(String.self, forKey: .dataStoreID)
        self.disallowFeedInRootFolder = try container.decode(Bool.self, forKey: .disallowFeedInRootFolder)
        self.containerID = try container.decodeIfPresent(ContainerIdentifier.self, forKey: .containerID)
        self.folders = try container.decode([ExtensionFolder].self, forKey: .folders)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.dataStoreID, forKey: .dataStoreID)
        try container.encode(self.disallowFeedInRootFolder, forKey: .disallowFeedInRootFolder)
        try container.encodeIfPresent(self.containerID, forKey: .containerID)
        try container.encode(self.folders, forKey: .folders)
    }

    func findFolder(forName name: String) -> ExtensionFolder? {
        self.folders.first(where: { $0.name == name })
    }
}

struct ExtensionFolder: ExtensionContainer, Sendable {
    enum CodingKeys: String, CodingKey {
        case dataStoreName = "accountName"
        case dataStoreID = "accountID"
        case name
        case containerID
    }

    let dataStoreName: String
    let dataStoreID: String
    let name: String
    let containerID: ContainerIdentifier?
}
