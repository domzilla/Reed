//
//  ContainerPath.swift
//  Reed
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Used to identify the parent of an object.
// Mainly used with deleting objects and undo/redo.
// Especially redo. The idea is to put something back in the right place.

public struct ContainerPath {
    private weak var dataStore: DataStore?
    private let names: [String] // empty if top-level of data store
    private let folderID: Int? // nil if top-level
    private let isTopLevel: Bool

    // folders should be from top-level down, as in ["Cats", "Tabbies"]

    @MainActor
    public init(dataStore: DataStore, folders: [Folder]) {
        self.dataStore = dataStore
        self.names = folders.map(\.nameForDisplay)
        self.isTopLevel = folders.isEmpty

        self.folderID = folders.last?.folderID
    }

    @MainActor
    public func resolveContainer() -> Container? {
        // The only time it should fail is if the data store no longer exists.
        // Otherwise the worst-case scenario is that it will create Folders if needed.

        guard let dataStore else {
            return nil
        }
        if self.isTopLevel {
            return dataStore
        }

        if let folderID, let folder = dataStore.existingFolder(withID: folderID) {
            return folder
        }

        return dataStore.ensureFolder(withFolderNames: self.names)
    }
}
