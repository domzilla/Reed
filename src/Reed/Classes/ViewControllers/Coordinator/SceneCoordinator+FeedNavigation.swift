//
//  SceneCoordinator+FeedNavigation.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func selectFirstUnreadInAllUnread() {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
            self.selectFeed(SmartFeedsController.shared.unreadFeed) {
                self.selectFirstUnreadArticleInTimeline()
            }
        }
    }

    func selectFeed(
        _ sidebarItem: SidebarItem?,
        animations: Animations = [],
        deselectArticle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let indexPath: IndexPath? = if let sidebarItem, let indexPath = indexPathFor(sidebarItem as AnyObject) {
            indexPath
        } else {
            nil
        }
        self.selectFeed(
            indexPath: indexPath,
            animations: animations,
            deselectArticle: deselectArticle,
            completion: completion
        )
        self.updateNavigationBarSubtitles(nil)
    }

    func selectFeed(
        indexPath: IndexPath?,
        animations: Animations = [],
        deselectArticle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard indexPath != self.currentFeedIndexPath else {
            completion?()
            return
        }

        self.currentFeedIndexPath = indexPath
        self.mainFeedCollectionViewController.updateFeedSelection(animations: animations)

        if deselectArticle {
            self.selectArticle(nil)
        }

        if let ip = indexPath, let node = nodeFor(ip), let sidebarItem = node.representedObject as? SidebarItem {
            self.rootSplitViewController.show(.supplementary)
            setTimelineFeed(sidebarItem, animated: false) {
                if self.isReadFeedsFiltered {
                    self.rebuildBackingStores()
                }
                AppDefaults.shared.selectedSidebarItem = sidebarItem.sidebarItemID
                completion?()
            }

        } else {
            setTimelineFeed(nil, animated: false) {
                if self.isReadFeedsFiltered {
                    self.rebuildBackingStores()
                }
                self.rootSplitViewController.show(.primary)
                AppDefaults.shared.selectedSidebarItem = nil
                completion?()
            }
        }
        self.updateNavigationBarSubtitles(nil)
    }

    func selectPrevFeed() {
        if let indexPath = prevFeedIndexPath {
            self.selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
        }
    }

    func selectNextFeed() {
        if let indexPath = nextFeedIndexPath {
            self.selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
        }
    }

    func selectTodayFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.todayFeed) {
            self.selectFeed(
                SmartFeedsController.shared.todayFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func selectAllUnreadFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
            self.selectFeed(
                SmartFeedsController.shared.unreadFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func selectStarredFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.starredFeed) {
            self.selectFeed(
                SmartFeedsController.shared.starredFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func discloseFeed(
        _ feed: Feed,
        initialLoad: Bool = false,
        animations: Animations = [],
        completion: (() -> Void)? = nil
    ) {
        guard let dataStore = feed.dataStore else {
            completion?()
            return
        }

        let parentFolder = dataStore.sortedFolders?.first(where: { $0.objectIsChild(feed) })

        markExpanded(dataStore)
        if let parentFolder {
            markExpanded(parentFolder)
        }

        if let feedSidebarItemID = feed.sidebarItemID {
            self.treeControllerDelegate.addFilterException(feedSidebarItemID)
        }
        if let parentFolderSidebarItemID = parentFolder?.sidebarItemID {
            self.treeControllerDelegate.addFilterException(parentFolderSidebarItemID)
        }

        rebuildBackingStores(initialLoad: initialLoad, completion: {
            self.treeControllerDelegate.resetFilterExceptions()
            self.selectFeed(nil) {
                if self.rootSplitViewController.traitCollection.horizontalSizeClass == .compact {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.selectFeed(feed, animations: animations, completion: completion)
                    }
                } else {
                    self.selectFeed(feed, animations: animations, completion: completion)
                }
            }
        })
    }

    func ensureFeedIsAvailableToSelect(_ sidebarItem: SidebarItem, completion: @escaping () -> Void) {
        self.addToFilterExceptionsIfNecessary(sidebarItem)
        self.addShadowTableToFilterExceptions()

        self.rebuildBackingStores(completion: {
            self.treeControllerDelegate.resetFilterExceptions()
            completion()
        })
    }

    func addToFilterExceptionsIfNecessary(_ sidebarItem: SidebarItem?) {
        if self.isReadFeedsFiltered, let sidebarItemID = sidebarItem?.sidebarItemID {
            if sidebarItem is SmartFeed {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
            } else if let folderFeed = sidebarItem as? Folder {
                if folderFeed.dataStore?.existingFolder(withID: folderFeed.folderID) != nil {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                }
            } else if let feed = sidebarItem as? Feed {
                if feed.dataStore?.existingFeed(withFeedID: feed.feedID) != nil {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                    self.addParentFolderToFilterExceptions(feed)
                }
            }
        }
    }

    private func addParentFolderToFilterExceptions(_ sidebarItem: SidebarItem) {
        guard
            let node = treeController.rootNode.descendantNodeRepresentingObject(sidebarItem as AnyObject),
            let folder = node.parent?.representedObject as? Folder,
            let folderSidebarItemID = folder.sidebarItemID else
        {
            return
        }

        self.treeControllerDelegate.addFilterException(folderSidebarItemID)
    }

    func addShadowTableToFilterExceptions() {
        for section in self.shadowTable {
            for feedNode in section.feedNodes {
                if let feed = feedNode.node.representedObject as? SidebarItem, let sidebarItemID = feed.sidebarItemID {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                }
            }
        }
    }
}
