//
//  SidebarTreeControllerDelegate.swift
//  Reed
//
//  Created by Brent Simmons on 7/24/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSTree

@MainActor
final class SidebarTreeControllerDelegate: TreeControllerDelegate {
    private var filterExceptions = Set<SidebarItemIdentifier>()
    var isReadFiltered = false

    func addFilterException(_ feedID: SidebarItemIdentifier) {
        self.filterExceptions.insert(feedID)
    }

    func resetFilterExceptions() {
        self.filterExceptions = Set<SidebarItemIdentifier>()
    }

    func treeController(treeController _: TreeController, childNodesFor node: Node) -> [Node]? {
        if node.isRoot {
            return childNodesForRootNode(node)
        }
        if node.representedObject is Container {
            return childNodesForContainerNode(node)
        }
        if node.representedObject is SmartFeedsController {
            return childNodesForSmartFeeds(node)
        }

        return nil
    }
}

extension SidebarTreeControllerDelegate {
    private func childNodesForRootNode(_ rootNode: Node) -> [Node]? {
        var topLevelNodes = [Node]()

        // Smart Feeds section
        let smartFeedsNode = rootNode.existingOrNewChildNode(with: SmartFeedsController.shared)
        smartFeedsNode.canHaveChildNodes = true
        smartFeedsNode.isGroupItem = true
        topLevelNodes.append(smartFeedsNode)

        // Feeds section - show feeds directly from the data store (no account grouping)
        let dataStore = DataStoreManager.shared.defaultDataStore
        if dataStore.isActive {
            let feedsNode = rootNode.existingOrNewChildNode(with: dataStore)
            feedsNode.canHaveChildNodes = true
            feedsNode.isGroupItem = true
            topLevelNodes.append(feedsNode)
        }

        return topLevelNodes
    }

    private func childNodesForSmartFeeds(_ parentNode: Node) -> [Node] {
        SmartFeedsController.shared.smartFeeds.compactMap { feed -> Node? in
            // All Smart Feeds should remain visible despite the Hide Read Feeds setting
            return parentNode.existingOrNewChildNode(with: feed as AnyObject)
        }
    }

    private func childNodesForContainerNode(_ containerNode: Node) -> [Node]? {
        let container = containerNode.representedObject as! Container

        var children = [AnyObject]()

        for feed in container.topLevelFeeds {
            if
                let sidebarItemID = feed.sidebarItemID,
                !(!filterExceptions.contains(sidebarItemID) && isReadFiltered && feed.unreadCount == 0)
            {
                children.append(feed)
            }
        }

        if let folders = container.folders {
            for folder in folders {
                if
                    let sidebarItemID = folder.sidebarItemID,
                    !(!filterExceptions.contains(sidebarItemID) && isReadFiltered && folder.unreadCount == 0)
                {
                    children.append(folder)
                }
            }
        }

        var updatedChildNodes = [Node]()

        for representedObject in children {
            if let existingNode = containerNode.childNodeRepresentingObject(representedObject) {
                if !updatedChildNodes.contains(existingNode) {
                    updatedChildNodes += [existingNode]
                    continue
                }
            }

            if let newNode = self.createNode(representedObject: representedObject, parent: containerNode) {
                updatedChildNodes += [newNode]
            }
        }

        return updatedChildNodes.sortedAlphabeticallyWithFoldersAtEnd()
    }

    private func createNode(representedObject: Any, parent: Node) -> Node? {
        if let feed = representedObject as? Feed {
            return self.createNode(feed: feed, parent: parent)
        }

        if let folder = representedObject as? Folder {
            return self.createNode(folder: folder, parent: parent)
        }

        return nil
    }

    private func createNode(feed: Feed, parent: Node) -> Node {
        parent.createChildNode(feed)
    }

    private func createNode(folder: Folder, parent: Node) -> Node {
        let node = parent.createChildNode(folder)
        node.canHaveChildNodes = true
        return node
    }
}
