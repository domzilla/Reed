//
//  ShareDefaultContainer.swift
//  Reed
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
struct ShareDefaultContainer {
    static func defaultContainer(containers: ExtensionContainers) -> ExtensionContainer? {
        if
            let dataStoreID = ShareAppDefaults.shared.addFeedAccountID,
            let dataStore = containers.dataStores.first(where: { $0.dataStoreID == dataStoreID })
        {
            if
                let folderName = ShareAppDefaults.shared.addFeedFolderName,
                let folder = dataStore.folders.first(where: { $0.name == folderName })
            {
                folder
            } else {
                self.substituteContainerIfNeeded(dataStore: dataStore)
            }
        } else if let dataStore = containers.dataStores.first {
            self.substituteContainerIfNeeded(dataStore: dataStore)
        } else {
            nil
        }
    }

    static func saveDefaultContainer(_ container: ExtensionContainer) {
        ShareAppDefaults.shared.addFeedAccountID = container.dataStoreID
        if let folder = container as? ExtensionFolder {
            ShareAppDefaults.shared.addFeedFolderName = folder.name
        } else {
            ShareAppDefaults.shared.addFeedFolderName = nil
        }
    }

    private static func substituteContainerIfNeeded(dataStore: ExtensionDataStore) -> ExtensionContainer? {
        if !dataStore.disallowFeedInRootFolder {
            dataStore
        } else {
            if let folder = dataStore.folders.first {
                folder
            } else {
                nil
            }
        }
    }
}
