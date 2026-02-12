//
//  ExtensionContainers+DataStore.swift
//  Reed
//
//  Extensions for ExtensionContainers that use main app types.
//

import Foundation

extension ExtensionDataStore {
    @MainActor
    init(dataStore: DataStore) {
        self.name = dataStore.nameForDisplay
        self.dataStoreID = dataStore.dataStoreID
        self.type = .cloudKit // CloudKit sync support
        self.disallowFeedInRootFolder = false // Feeds allowed in root folder
        self.containerID = dataStore.containerID
        self.folders = dataStore.sortedFolders?.map { ExtensionFolder(folder: $0) } ?? [ExtensionFolder]()
    }
}

extension ExtensionFolder {
    @MainActor
    init(folder: Folder) {
        self.dataStoreName = folder.dataStore?.nameForDisplay ?? ""
        self.dataStoreID = folder.dataStore?.dataStoreID ?? ""
        self.name = folder.nameForDisplay
        self.containerID = folder.containerID
    }
}
