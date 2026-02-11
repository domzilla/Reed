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
        let accountNodes: [Node] = AccountManager.shared.sortedActiveAccounts.map { account in
            let accountNode = Node(representedObject: account, parent: node)
            accountNode.canHaveChildNodes = true
            return accountNode
        }
        return accountNodes
    }

    private func childNodes(_ node: Node) -> [Node]? {
        guard let account = node.representedObject as? Account, let folders = account.folders else {
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
