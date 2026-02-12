//
//  AddFeedDefaultContainer.swift
//  Reed
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
struct AddFeedDefaultContainer {
    static var defaultContainer: Container? {
        let dataStore = DataStore.shared
        guard dataStore.isActive else { return nil }

        if
            let folderName = AppDefaults.shared.addFeedFolderName,
            let folder = dataStore.existingFolder(withDisplayName: folderName)
        {
            return folder
        }

        return dataStore
    }

    static func saveDefaultContainer(_ container: Container) {
        AppDefaults.shared.addFeedAccountID = container.dataStore?.dataStoreID
        if let folder = container as? Folder {
            AppDefaults.shared.addFeedFolderName = folder.nameForDisplay
        } else {
            AppDefaults.shared.addFeedFolderName = nil
        }
    }
}
