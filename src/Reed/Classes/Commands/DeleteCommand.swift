//
//  DeleteCommand.swift
//  Reed
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSTree

final class DeleteCommand: UndoableCommand {
    let treeController: TreeController?
    let undoManager: UndoManager
    let undoActionName: String
    var redoActionName: String {
        self.undoActionName
    }

    let errorHandler: (Error) -> Void

    private let itemSpecifiers: [SidebarItemSpecifier]

    @MainActor
    init?(
        nodesToDelete: [Node],
        treeController: TreeController? = nil,
        undoManager: UndoManager,
        errorHandler: @escaping (Error) -> Void
    ) {
        guard DeleteCommand.canDelete(nodesToDelete) else {
            return nil
        }
        guard let actionName = DeleteActionName.name(for: nodesToDelete) else {
            return nil
        }

        self.treeController = treeController
        self.undoActionName = actionName
        self.undoManager = undoManager
        self.errorHandler = errorHandler

        let itemSpecifiers = nodesToDelete.compactMap { SidebarItemSpecifier(node: $0, errorHandler: errorHandler) }
        guard !itemSpecifiers.isEmpty else {
            return nil
        }
        self.itemSpecifiers = itemSpecifiers
    }

    func perform() {
        let group = DispatchGroup()
        for itemSpecifier in self.itemSpecifiers {
            group.enter()
            itemSpecifier.delete {
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) {
            MainActor.assumeIsolated {
                self.treeController?.rebuild()
                self.registerUndo()
            }
        }
    }

    func undo() {
        self.itemSpecifiers.forEach { $0.restore() }
        registerRedo()
    }

    @MainActor
    static func canDelete(_ nodes: [Node]) -> Bool {
        // Return true if all nodes are feeds and folders.
        // Any other type: return false.

        if nodes.isEmpty {
            return false
        }

        for node in nodes {
            if let _ = node.representedObject as? Feed {
                continue
            }
            if let _ = node.representedObject as? Folder {
                continue
            }
            return false
        }

        return true
    }
}

// Remember as much as we can now about the items being deleted,
// so they can be restored to the correct place.

@MainActor
private struct SidebarItemSpecifier {
    private weak var dataStore: DataStore?
    private let parentFolder: Folder?
    private let folder: Folder?
    private let feed: Feed?
    private let path: ContainerPath
    private let errorHandler: (Error) -> Void

    private var container: Container? {
        if let parentFolder {
            return parentFolder
        }
        if let dataStore {
            return dataStore
        }
        return nil
    }

    @MainActor
    init?(node: Node, errorHandler: @escaping (Error) -> Void) {
        var dataStore: DataStore?

        self.parentFolder = node.parentFolder()

        if let feed = node.representedObject as? Feed {
            self.feed = feed
            self.folder = nil
            dataStore = feed.dataStore
        } else if let folder = node.representedObject as? Folder {
            self.feed = nil
            self.folder = folder
            dataStore = folder.dataStore
        } else {
            return nil
        }
        if dataStore == nil {
            return nil
        }

        self.dataStore = dataStore!
        self.path = ContainerPath(dataStore: dataStore!, folders: node.containingFolders())

        self.errorHandler = errorHandler
    }

    func delete(completion: @escaping () -> Void) {
        if let feed {
            guard let container = path.resolveContainer() else {
                completion()
                return
            }

            BatchUpdate.shared.start()
            self.dataStore?.removeFeed(feed, from: container) { result in
                BatchUpdate.shared.end()
                completion()
                self.checkResult(result)
            }

        } else if let folder {
            BatchUpdate.shared.start()
            self.dataStore?.removeFolder(folder) { result in
                BatchUpdate.shared.end()
                completion()
                self.checkResult(result)
            }
        }
    }

    func restore() {
        if let _ = feed {
            self.restoreFeed()
        } else if let _ = folder {
            self.restoreFolder()
        }
    }

    private func restoreFeed() {
        guard let dataStore, let feed, let container = path.resolveContainer() else {
            return
        }

        BatchUpdate.shared.start()
        dataStore.restoreFeed(feed, container: container) { result in
            BatchUpdate.shared.end()
            self.checkResult(result)
        }
    }

    private func restoreFolder() {
        guard let dataStore, let folder else {
            return
        }

        BatchUpdate.shared.start()
        dataStore.restoreFolder(folder) { result in
            BatchUpdate.shared.end()
            self.checkResult(result)
        }
    }

    private func checkResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            break
        case let .failure(error):
            self.errorHandler(error)
        }
    }
}

@MainActor
extension Node {
    fileprivate func parentFolder() -> Folder? {
        guard let parentNode = self.parent else {
            return nil
        }
        if parentNode.isRoot {
            return nil
        }
        if let folder = parentNode.representedObject as? Folder {
            return folder
        }
        return nil
    }

    fileprivate func containingFolders() -> [Folder] {
        var nomad = self.parent
        var folders = [Folder]()

        while nomad != nil {
            if let folder = nomad!.representedObject as? Folder {
                folders += [folder]
            } else {
                break
            }
            nomad = nomad!.parent
        }

        return folders.reversed()
    }
}

private enum DeleteActionName {
    private static let deleteFeed = NSLocalizedString("Delete Feed", comment: "command")
    private static let deleteFeeds = NSLocalizedString("Delete Feeds", comment: "command")
    private static let deleteFolder = NSLocalizedString("Delete Folder", comment: "command")
    private static let deleteFolders = NSLocalizedString("Delete Folders", comment: "command")
    private static let deleteFeedsAndFolders = NSLocalizedString("Delete Feeds and Folders", comment: "command")

    @MainActor
    static func name(for nodes: [Node]) -> String? {
        var numberOfFeeds = 0
        var numberOfFolders = 0

        for node in nodes {
            if let _ = node.representedObject as? Feed {
                numberOfFeeds += 1
            } else if let _ = node.representedObject as? Folder {
                numberOfFolders += 1
            } else {
                return nil // Delete only Feeds and Folders.
            }
        }

        if numberOfFolders < 1 {
            return numberOfFeeds == 1 ? self.deleteFeed : self.deleteFeeds
        }
        if numberOfFeeds < 1 {
            return numberOfFolders == 1 ? self.deleteFolder : self.deleteFolders
        }

        return self.deleteFeedsAndFolders
    }
}
