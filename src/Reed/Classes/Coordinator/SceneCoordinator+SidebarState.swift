//
//  SceneCoordinator+SidebarState.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func nodeFor(sidebarItemID: SidebarItemIdentifier) -> Node? {
        self.treeController.rootNode.descendantNode(where: { node in
            if let sidebarItem = node.representedObject as? SidebarItem {
                sidebarItem.sidebarItemID == sidebarItemID
            } else {
                false
            }
        })
    }

    func numberOfSections() -> Int {
        self.shadowTable.count
    }

    func numberOfRows(in section: Int) -> Int {
        self.shadowTable[section].feedNodes.count
    }

    func nodeFor(_ indexPath: IndexPath) -> Node? {
        guard
            indexPath.section > -1,
            indexPath.row > -1,
            indexPath.section < self.shadowTable.count,
            indexPath.row < self.shadowTable[indexPath.section].feedNodes.count else
        {
            return nil
        }
        return self.shadowTable[indexPath.section].feedNodes[indexPath.row].node
    }

    func indexPathFor(_ node: Node) -> IndexPath? {
        for i in 0..<self.shadowTable.count {
            if let row = shadowTable[i].feedNodes.firstIndex(of: FeedNode(node)) {
                return IndexPath(row: row, section: i)
            }
        }
        return nil
    }

    func isExpanded(_ containerID: ContainerIdentifier) -> Bool {
        self.expandedContainers.contains(containerID)
    }

    func isExpanded(_ containerIdentifiable: ContainerIdentifiable) -> Bool {
        if let containerID = containerIdentifiable.containerID {
            return self.isExpanded(containerID)
        }
        return false
    }

    func isExpanded(_ node: Node) -> Bool {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            return self.isExpanded(containerIdentifiable)
        }
        return false
    }

    func expand(_ containerID: ContainerIdentifier) {
        self.markExpanded(containerID)
        self.rebuildBackingStores()
        self.saveExpandedContainersToUserDefaults()
    }

    /// This is a special function that expects the caller to change the disclosure arrow state outside this function.
    /// Failure to do so will get the Sidebar into an invalid state.
    func expand(_ node: Node) {
        guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
        self.lastExpandedContainers.insert(containerID)
        self.expand(containerID)
    }

    func expandAllSectionsAndFolders() {
        for sectionNode in self.treeController.rootNode.childNodes {
            self.markExpanded(sectionNode)
            for topLevelNode in sectionNode.childNodes {
                if topLevelNode.representedObject is Folder {
                    self.markExpanded(topLevelNode)
                }
            }
        }
        self.rebuildBackingStores()
        self.saveExpandedContainersToUserDefaults()
    }

    func collapse(_ containerID: ContainerIdentifier) {
        self.unmarkExpanded(containerID)
        self.rebuildBackingStores()
        self.clearTimelineIfNoLongerAvailable()
        self.saveExpandedContainersToUserDefaults()
    }

    /// This is a special function that expects the caller to change the disclosure arrow state outside this function.
    /// Failure to do so will get the Sidebar into an invalid state.
    func collapse(_ node: Node) {
        guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
        self.lastExpandedContainers.remove(containerID)
        self.collapse(containerID)
    }

    func collapseAllFolders() {
        for sectionNode in self.treeController.rootNode.childNodes {
            for topLevelNode in sectionNode.childNodes {
                if topLevelNode.representedObject is Folder {
                    self.unmarkExpanded(topLevelNode)
                }
            }
        }
        self.rebuildBackingStores()
        self.clearTimelineIfNoLongerAvailable()
    }

    func mainFeedIndexPathForCurrentTimeline() -> IndexPath? {
        guard let node = treeController.rootNode.descendantNodeRepresentingObject(timelineFeed as AnyObject) else {
            return nil
        }
        return self.indexPathFor(node)
    }

    // MARK: - Backing Store Management

    func queueRebuildBackingStores() {
        self.rebuildBackingStoresQueue.add(self, #selector(self.rebuildBackingStoresWithDefaults))
    }

    @objc
    func rebuildBackingStoresWithDefaults() {
        self.rebuildBackingStores()
    }

    func rebuildBackingStores(
        initialLoad: Bool = false,
        updateExpandedNodes: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        if !BatchUpdate.shared.isPerforming {
            self.addToFilterExceptionsIfNecessary(self.timelineFeed)
            self.treeController.rebuild()
            self.treeControllerDelegate.resetFilterExceptions()

            updateExpandedNodes?()
            let changes = self.rebuildShadowTable()
            self.mainFeedCollectionViewController.reloadFeeds(
                initialLoad: initialLoad,
                changes: changes,
                completion: completion
            )
        }
    }

    func rebuildShadowTable() -> ShadowTableChanges {
        var newShadowTable = [(sectionID: String, feedNodes: [FeedNode])]()

        for i in 0..<self.treeController.rootNode.numberOfChildNodes {
            var feedNodes = [FeedNode]()
            let sectionNode = self.treeController.rootNode.childAtIndex(i)!

            if self.isExpanded(sectionNode) {
                for node in sectionNode.childNodes {
                    feedNodes.append(FeedNode(node))
                    if self.isExpanded(node) {
                        for child in node.childNodes {
                            feedNodes.append(FeedNode(child))
                        }
                    }
                }
            }

            let sectionID = (sectionNode.representedObject as? DataStore)?.dataStoreID ?? ""
            newShadowTable.append((sectionID: sectionID, feedNodes: feedNodes))
        }

        // If we have a current Feed IndexPath it is no longer valid and needs reset.
        if self.currentFeedIndexPath != nil {
            self.currentFeedIndexPath = self.indexPathFor(self.timelineFeed as AnyObject)
        }

        // Compute the differences in the shadow table rows and the expanded table entries
        var changes = [ShadowTableChanges.RowChanges]()
        let expandedTableDifference = self.lastExpandedContainers.symmetricDifference(self.expandedContainers)

        for (section, newSectionRows) in newShadowTable.enumerated() {
            var moves = Set<ShadowTableChanges.Move>()
            var inserts = Set<Int>()
            var deletes = Set<Int>()

            let oldFeedNodes = self.shadowTable.first(where: { $0.sectionID == newSectionRows.sectionID })?
                .feedNodes ?? [FeedNode]()

            let diff = newSectionRows.feedNodes.difference(from: oldFeedNodes).inferringMoves()
            for change in diff {
                switch change {
                case let .insert(offset, _, associated):
                    if let associated {
                        moves.insert(ShadowTableChanges.Move(associated, offset))
                    } else {
                        inserts.insert(offset)
                    }
                case let .remove(offset, _, associated):
                    if let associated {
                        moves.insert(ShadowTableChanges.Move(offset, associated))
                    } else {
                        deletes.insert(offset)
                    }
                }
            }

            // We need to reload the difference in expanded rows to get the disclosure arrows correct when
            // programmatically changing their state
            var reloads = Set<Int>()

            for (index, newFeedNode) in newSectionRows.feedNodes.enumerated() {
                if let newFeedNodeContainerID = (newFeedNode.node.representedObject as? Container)?.containerID {
                    if expandedTableDifference.contains(newFeedNodeContainerID) {
                        reloads.insert(index)
                    }
                }
            }

            changes.append(ShadowTableChanges.RowChanges(
                section: section,
                deletes: deletes,
                inserts: inserts,
                reloads: reloads,
                moves: moves
            ))
        }

        self.lastExpandedContainers = self.expandedContainers

        // Compute the difference in the shadow table sections
        var moves = Set<ShadowTableChanges.Move>()
        var inserts = Set<Int>()
        var deletes = Set<Int>()

        let oldSections = self.shadowTable.map(\.sectionID)
        let newSections = newShadowTable.map(\.sectionID)
        let diff = newSections.difference(from: oldSections).inferringMoves()
        for change in diff {
            switch change {
            case let .insert(offset, _, associated):
                if let associated {
                    moves.insert(ShadowTableChanges.Move(associated, offset))
                } else {
                    inserts.insert(offset)
                }
            case let .remove(offset, _, associated):
                if let associated {
                    moves.insert(ShadowTableChanges.Move(offset, associated))
                } else {
                    deletes.insert(offset)
                }
            }
        }

        self.shadowTable = newShadowTable

        return ShadowTableChanges(deletes: deletes, inserts: inserts, moves: moves, rowChanges: changes)
    }

    func shadowTableContains(_ sidebarItem: SidebarItem) -> Bool {
        for section in self.shadowTable {
            for feedNode in section.feedNodes {
                if
                    let nodeSidebarItem = feedNode.node.representedObject as? SidebarItem,
                    nodeSidebarItem.sidebarItemID == sidebarItem.sidebarItemID
                {
                    return true
                }
            }
        }
        return false
    }

    func clearTimelineIfNoLongerAvailable() {
        if let feed = timelineFeed, !shadowTableContains(feed) {
            self.selectFeed(nil, deselectArticle: true)
        }
    }

    func indexPathFor(_ object: AnyObject) -> IndexPath? {
        guard let node = treeController.rootNode.descendantNodeRepresentingObject(object) else {
            return nil
        }
        return self.indexPathFor(node)
    }

    // MARK: - Expansion State

    func markExpanded(_ containerID: ContainerIdentifier) {
        self.expandedContainers.insert(containerID)
    }

    func markExpanded(_ containerIdentifiable: ContainerIdentifiable) {
        if let containerID = containerIdentifiable.containerID {
            self.markExpanded(containerID)
        }
    }

    func markExpanded(_ node: Node) {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            self.markExpanded(containerIdentifiable)
        }
    }

    func unmarkExpanded(_ containerID: ContainerIdentifier) {
        self.expandedContainers.remove(containerID)
    }

    func unmarkExpanded(_ containerIdentifiable: ContainerIdentifiable) {
        if let containerID = containerIdentifiable.containerID {
            self.unmarkExpanded(containerID)
        }
    }

    func unmarkExpanded(_ node: Node) {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            self.unmarkExpanded(containerIdentifiable)
        }
    }

    func saveExpandedContainersToUserDefaults() {
        AppDefaults.shared.expandedContainers = self.expandedContainers
    }
}
