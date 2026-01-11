//
//  SidebarTreeControllerDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/24/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSTree

@MainActor final class SidebarTreeControllerDelegate: TreeControllerDelegate {

	private var filterExceptions = Set<SidebarItemIdentifier>()
	var isReadFiltered = false

	func addFilterException(_ feedID: SidebarItemIdentifier) {
		filterExceptions.insert(feedID)
	}

	func resetFilterExceptions() {
		filterExceptions = Set<SidebarItemIdentifier>()
	}

	func treeController(treeController: TreeController, childNodesFor node: Node) -> [Node]? {
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

private extension SidebarTreeControllerDelegate {

	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {
		var topLevelNodes = [Node]()

		// Smart Feeds section
		let smartFeedsNode = rootNode.existingOrNewChildNode(with: SmartFeedsController.shared)
		smartFeedsNode.canHaveChildNodes = true
		smartFeedsNode.isGroupItem = true
		topLevelNodes.append(smartFeedsNode)

		// Feeds section - show feeds directly from the single iCloud account (no account grouping)
		let account = AccountManager.shared.defaultAccount
		if account.isActive {
			let feedsNode = rootNode.existingOrNewChildNode(with: account)
			feedsNode.canHaveChildNodes = true
			feedsNode.isGroupItem = true
			topLevelNodes.append(feedsNode)
		}

		return topLevelNodes
	}

	func childNodesForSmartFeeds(_ parentNode: Node) -> [Node] {
		return SmartFeedsController.shared.smartFeeds.compactMap { (feed) -> Node? in
			// All Smart Feeds should remain visible despite the Hide Read Feeds setting
			return parentNode.existingOrNewChildNode(with: feed as AnyObject)
		}
	}

	func childNodesForContainerNode(_ containerNode: Node) -> [Node]? {
		let container = containerNode.representedObject as! Container

		var children = [AnyObject]()

		for feed in container.topLevelFeeds {
			if let sidebarItemID = feed.sidebarItemID, !(!filterExceptions.contains(sidebarItemID) && isReadFiltered && feed.unreadCount == 0) {
				children.append(feed)
			}
		}

		if let folders = container.folders {
			for folder in folders {
				if let sidebarItemID = folder.sidebarItemID, !(!filterExceptions.contains(sidebarItemID) && isReadFiltered && folder.unreadCount == 0) {
					children.append(folder)
				}
			}
		}

		var updatedChildNodes = [Node]()

		children.forEach { (representedObject) in

			if let existingNode = containerNode.childNodeRepresentingObject(representedObject) {
				if !updatedChildNodes.contains(existingNode) {
					updatedChildNodes += [existingNode]
					return
				}
			}

			if let newNode = self.createNode(representedObject: representedObject, parent: containerNode) {
				updatedChildNodes += [newNode]
			}
		}

		return updatedChildNodes.sortedAlphabeticallyWithFoldersAtEnd()
	}

	func createNode(representedObject: Any, parent: Node) -> Node? {
		if let feed = representedObject as? Feed {
			return createNode(feed: feed, parent: parent)
		}

		if let folder = representedObject as? Folder {
			return createNode(folder: folder, parent: parent)
		}

		return nil
	}

	func createNode(feed: Feed, parent: Node) -> Node {
		return parent.createChildNode(feed)
	}

	func createNode(folder: Folder, parent: Node) -> Node {
		let node = parent.createChildNode(folder)
		node.canHaveChildNodes = true
		return node
	}
}
