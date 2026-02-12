//
//  FolderTreeControllerDelegate.swift
//  Reed
//
//  Created by Brent Simmons on 8/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSTree

@MainActor
final class FolderTreeControllerDelegate: TreeControllerDelegate {
    func treeController(treeController _: TreeController, childNodesFor node: Node) -> [Node]? {
        node.isRoot ? childNodesForRootNode(node) : childNodes(node)
    }
}

@MainActor
extension FolderTreeControllerDelegate {
    private func childNodesForRootNode(_ node: Node) -> [Node]? {
        let dataStoreNodes: [Node] = DataStore.shared.sortedActiveDataStores.map { dataStore in
            let dataStoreNode = Node(representedObject: dataStore, parent: node)
            dataStoreNode.canHaveChildNodes = true
            return dataStoreNode
        }
        return dataStoreNodes
    }

    private func childNodes(_ node: Node) -> [Node]? {
        guard let dataStore = node.representedObject as? DataStore, let folders = dataStore.folders else {
            return nil
        }

        let folderNodes: [Node] = folders.map { self.createNode($0, parent: node) }
        return folderNodes.sortedAlphabetically()
    }

    private func createNode(_ folder: Folder, parent: Node) -> Node {
        let node = Node(representedObject: folder, parent: parent)
        node.canHaveChildNodes = false
        return node
    }
}
