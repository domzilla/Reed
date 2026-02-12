//
//  MainFeedCollectionViewController+KeyboardCommands.swift
//  Reed
//
//  Created by Dominic Rodemer on 12/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

// MARK: - Keyboard Shortcuts

extension MainFeedCollectionViewController {
    @objc
    func collapseAllExceptForGroupItems(_: Any?) {
        self.coordinator.collapseAllFolders()
    }

    @objc
    func collapseSelectedRows(_: Any?) {
        if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
            self.coordinator.collapse(node)
            if let folder = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
                folder.disclosureExpanded = false
            }
        }
    }

    @objc
    override func delete(_: Any?) {
        if let indexPath = coordinator.currentFeedIndexPath {
            self.delete(indexPath: indexPath)
        }
    }

    @objc
    func expandAll(_: Any?) {
        self.coordinator.expandAllSectionsAndFolders()
    }

    @objc
    func expandSelectedRows(_: Any?) {
        if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
            self.coordinator.expand(node)
            if let folder = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
                folder.disclosureExpanded = true
            }
        }
    }

    @objc
    func markAllAsRead(_: Any) {
        guard
            let indexPath = collectionView.indexPathsForSelectedItems?.first,
            let contentView = collectionView.cellForItem(at: indexPath)?.contentView else
        {
            return
        }

        let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
        MarkAsReadAlertController.confirm(self, confirmTitle: title, sourceType: contentView) { [weak self] in
            self?.coordinator.markAllAsReadInTimeline()
        }
    }

    @objc
    func navigateToTimeline(_: Any?) {
        self.coordinator.navigateToTimeline()
    }

    @objc
    func openInBrowser(_: Any?) {
        self.coordinator.showBrowserForCurrentFeed()
    }

    @objc
    func selectNextDown(_: Any?) {
        self.coordinator.selectNextFeed()
    }

    @objc
    func selectNextUp(_: Any?) {
        self.coordinator.selectPrevFeed()
    }

    @objc
    func showFeedInspector(_: Any?) {
        self.coordinator.showFeedInspector()
    }
}
