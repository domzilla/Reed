//
//  ExtensionContainers+DataStore.swift
//  Reed
//
//  Extensions for ExtensionContainers that use main app types.
//

import Foundation

extension ExtensionAccount {
    @MainActor
    init(dataStore: DataStore) {
        self.name = dataStore.nameForDisplay
        self.accountID = dataStore.dataStoreID
        self.type = .cloudKit // CloudKit sync support
        self.disallowFeedInRootFolder = false // Feeds allowed in root folder
        self.containerID = dataStore.containerID
        self.folders = dataStore.sortedFolders?.map { ExtensionFolder(folder: $0) } ?? [ExtensionFolder]()
    }
}

extension ExtensionFolder {
    @MainActor
    init(folder: Folder) {
        self.accountName = folder.dataStore?.nameForDisplay ?? ""
        self.accountID = folder.dataStore?.dataStoreID ?? ""
        self.name = folder.nameForDisplay
        self.containerID = folder.containerID
    }
}
