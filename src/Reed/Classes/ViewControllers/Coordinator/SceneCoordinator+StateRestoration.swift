//
//  SceneCoordinator+StateRestoration.swift
//  Reed
//

import UIKit
import UserNotifications

extension SceneCoordinator {
    func restoreWindowState(activity _: NSUserActivity?) {
        let stateInfo = StateRestorationInfo()
        self.restoreWindowState(stateInfo)
    }

    func handle(_: NSUserActivity) {
        // Activity handling removed - no longer using Handoff/Spotlight
    }

    func handle(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        self.handleReadArticle(userInfo)
    }

    // MARK: - Private

    private func restoreWindowState(_ stateInfo: StateRestorationInfo) {
        if AppDefaults.shared.isFirstRun {
            // Expand top-level items on first run.
            for sectionNode in self.treeController.rootNode.childNodes {
                markExpanded(sectionNode)
            }
            saveExpandedContainersToUserDefaults()
        } else {
            self.expandedContainers = stateInfo.expandedContainers
        }

        self.sidebarItemsHidingReadArticles.formUnion(stateInfo.sidebarItemsHidingReadArticles)

        rebuildBackingStores(initialLoad: true)

        // You can't assign the Feeds Read Filter until we've built the backing stores at least once or there is nothing
        // for state restoration to work with while we are waiting for the unread counts to initialize.
        self.treeControllerDelegate.isReadFiltered = stateInfo.hideReadFeeds

        self.restoreSelectedSidebarItemAndArticle(stateInfo)
    }

    private func restoreSelectedSidebarItemAndArticle(_ stateInfo: StateRestorationInfo) {
        guard let selectedSidebarItem = stateInfo.selectedSidebarItem else {
            return
        }

        guard
            let feedNode = nodeFor(sidebarItemID: selectedSidebarItem),
            let indexPath = indexPathFor(feedNode) else
        {
            return
        }
        self.selectFeed(indexPath: indexPath, animations: []) {
            self.restoreSelectedArticle(stateInfo)
        }
    }

    private func restoreSelectedArticle(_ stateInfo: StateRestorationInfo) {
        guard let articleSpecifier = stateInfo.selectedArticle else {
            return
        }

        let article = self.articles.article(matching: articleSpecifier) ??
            DataStore.shared.fetchArticle(
                dataStoreID: articleSpecifier.accountID,
                articleID: articleSpecifier.articleID
            )

        if let article {
            self.selectArticle(
                article,
                isShowingExtractedArticle: stateInfo.isShowingExtractedArticle,
                articleWindowScrollY: stateInfo.articleWindowScrollY
            )
        }
    }

    func windowState() -> [AnyHashable: Any] {
        let containerExpandedWindowState = self.expandedContainers.map(\.userInfo)
        var readArticlesFilterState = [[AnyHashable: AnyHashable]: Bool]()
        for sidebarItemID in self.sidebarItemsHidingReadArticles {
            readArticlesFilterState[sidebarItemID.userInfo] = true
        }
        return [
            AppConstants.StateRestorationKey.readFeedsFilterState: self.isReadFeedsFiltered,
            AppConstants.StateRestorationKey.containerExpandedWindowState: containerExpandedWindowState,
            AppConstants.StateRestorationKey.readArticlesFilterState: readArticlesFilterState,
        ]
    }

    func handleSelectFeed(_ userInfo: [AnyHashable: Any]?) {
        guard
            let userInfo,
            let sidebarItemIDUserInfo = userInfo[AppConstants.StateRestorationKey.sidebarItemID] as? [String: String],
            let sidebarItemID = SidebarItemIdentifier(userInfo: sidebarItemIDUserInfo) else
        {
            return
        }

        self.treeControllerDelegate.addFilterException(sidebarItemID)

        switch sidebarItemID {
        case .smartFeed:
            guard let smartFeed = SmartFeedsController.shared.find(by: sidebarItemID) else { return }

            self.markExpanded(SmartFeedsController.shared)
            self.rebuildBackingStores(initialLoad: true, completion: {
                self.treeControllerDelegate.resetFilterExceptions()
                if let indexPath = self.indexPathFor(smartFeed) {
                    self.selectFeed(indexPath: indexPath) {
                        self.mainFeedCollectionViewController.focus()
                    }
                }
            })

        case .script:
            break

        case let .folder(accountID, folderName):
            guard
                let dataStoreNode = self.findDataStoreNode(dataStoreID: accountID),
                let dataStore = dataStoreNode.representedObject as? DataStore else
            {
                return
            }

            self.markExpanded(dataStore)

            self.rebuildBackingStores(initialLoad: true, completion: {
                self.treeControllerDelegate.resetFilterExceptions()

                if
                    let folderNode = self.findFolderNode(folderName: folderName, beginningAt: dataStoreNode),
                    let indexPath = self.indexPathFor(folderNode)
                {
                    self.selectFeed(indexPath: indexPath) {
                        self.mainFeedCollectionViewController.focus()
                    }
                }
            })

        case let .feed(accountID, feedID):
            guard
                let dataStoreNode = findDataStoreNode(dataStoreID: accountID),
                let dataStore = dataStoreNode.representedObject as? DataStore,
                let feed = dataStore.existingFeed(withFeedID: feedID) else
            {
                return
            }

            self.discloseFeed(feed, initialLoad: true) {
                self.mainFeedCollectionViewController.focus()
            }
        }
    }

    func handleReadArticle(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return }

        guard
            let articlePathUserInfo = userInfo[AppConstants.NotificationKey.articlePath] as? [AnyHashable: Any],
            let dataStoreID = articlePathUserInfo[ArticlePathKey.dataStoreID] as? String,
            let dataStoreName = articlePathUserInfo[ArticlePathKey.dataStoreName] as? String,
            let feedID = articlePathUserInfo[ArticlePathKey.feedID] as? String,
            let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String,
            let dataStoreNode = findDataStoreNode(dataStoreID: dataStoreID, dataStoreName: dataStoreName),
            let dataStore = dataStoreNode.representedObject as? DataStore else
        {
            return
        }

        self.exceptionArticleFetcher = SingleArticleFetcher(dataStore: dataStore, articleID: articleID)

        if self.restoreFeedSelection(userInfo, dataStoreID: dataStoreID, feedID: feedID, articleID: articleID) {
            return
        }

        guard let feed = dataStore.existingFeed(withFeedID: feedID) else {
            return
        }

        self.discloseFeed(feed) {
            self.selectArticleInCurrentFeed(articleID)
        }
    }

    private func restoreFeedSelection(
        _ userInfo: [AnyHashable: Any],
        dataStoreID _: String,
        feedID _: String,
        articleID: String
    )
        -> Bool
    {
        guard
            let sidebarItemIDUserInfo =
            (userInfo[AppConstants.StateRestorationKey.sidebarItemID] ??
                userInfo[AppConstants.StateRestorationKey.feedIdentifier]) as? [String: String],
            let sidebarItemID = SidebarItemIdentifier(userInfo: sidebarItemIDUserInfo) else
        {
            return false
        }

        // Read values from UserDefaults (migration happens in restoreWindowState)
        let isShowingExtractedArticle = AppDefaults.shared.isShowingExtractedArticle
        let articleWindowScrollY = AppDefaults.shared.articleWindowScrollY

        switch sidebarItemID {
        case .script:
            return false

        case .smartFeed, .folder:
            let found = self.selectFeedAndArticle(
                sidebarItemID: sidebarItemID,
                articleID: articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
            if found {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
            }
            return found

        case .feed:
            let found = self.selectFeedAndArticle(
                sidebarItemID: sidebarItemID,
                articleID: articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
            if found {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
                if
                    let feedNode = nodeFor(sidebarItemID: sidebarItemID),
                    let folder = feedNode.parent?.representedObject as? Folder,
                    let folderSidebarItemID = folder.sidebarItemID
                {
                    self.treeControllerDelegate.addFilterException(folderSidebarItemID)
                }
            }
            return found
        }
    }

    private func findDataStoreNode(dataStoreID: String, dataStoreName: String? = nil) -> Node? {
        if
            let node = treeController.rootNode
                .descendantNode(where: { ($0.representedObject as? DataStore)?.dataStoreID == dataStoreID })
        {
            return node
        }

        if
            let dataStoreName,
            let node = treeController.rootNode
                .descendantNode(where: { ($0.representedObject as? DataStore)?.nameForDisplay == dataStoreName })
        {
            return node
        }

        return nil
    }

    private func findFolderNode(folderName: String, beginningAt startingNode: Node) -> Node? {
        if
            let node = startingNode
                .descendantNode(where: { ($0.representedObject as? Folder)?.nameForDisplay == folderName })
        {
            return node
        }
        return nil
    }

    private func findFeedNode(feedID: String, beginningAt startingNode: Node) -> Node? {
        if let node = startingNode.descendantNode(where: { ($0.representedObject as? Feed)?.feedID == feedID }) {
            return node
        }
        return nil
    }

    private func selectFeedAndArticle(
        sidebarItemID: SidebarItemIdentifier,
        articleID: String,
        isShowingExtractedArticle: Bool,
        articleWindowScrollY: Int
    )
        -> Bool
    {
        guard
            let feedNode = nodeFor(sidebarItemID: sidebarItemID),
            let feedIndexPath = indexPathFor(feedNode) else { return false }

        self.selectFeed(indexPath: feedIndexPath) {
            self.selectArticleInCurrentFeed(
                articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
        }

        return true
    }
}
