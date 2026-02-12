//
//  SceneCoordinator+Search.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func showSearch() {
        self.selectFeed(indexPath: nil) {
            self.rootSplitViewController.show(.supplementary)
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.mainTimelineViewController!.showSearchAll()
            }
        }
    }

    func toggleReadFeedsFilter() {
        if self.isReadFeedsFiltered {
            self.treeControllerDelegate.isReadFiltered = false
            AppDefaults.shared.hideReadFeeds = false
        } else {
            self.treeControllerDelegate.isReadFiltered = true
            AppDefaults.shared.hideReadFeeds = true
        }
        rebuildBackingStores()
        self.mainFeedCollectionViewController?.updateUI()
    }

    func toggleReadArticlesFilter() {
        guard let sidebarItemID = timelineFeed?.sidebarItemID else {
            return
        }

        if self.isReadArticlesFiltered {
            self.sidebarItemsHidingReadArticles.remove(sidebarItemID)
        } else {
            self.sidebarItemsHidingReadArticles.insert(sidebarItemID)
        }

        self.refreshTimeline(resetScroll: false)
    }

    func beginSearching() {
        self.isSearching = true
        self.preSearchTimelineFeed = self.timelineFeed
        self.savedSearchArticles = self.articles
        self.savedSearchArticleIds = Set(self.articles.map(\.articleID))
        setTimelineFeed(nil, animated: true)
        self.selectArticle(nil)
    }

    func endSearching() {
        if let oldTimelineFeed = preSearchTimelineFeed {
            emptyTheTimeline()
            self.timelineFeed = oldTimelineFeed
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: true)
            replaceArticles(with: self.savedSearchArticles!, animated: true)
        } else {
            setTimelineFeed(nil, animated: true)
        }

        self.lastSearchString = ""
        self.lastSearchScope = nil
        self.preSearchTimelineFeed = nil
        self.savedSearchArticleIds = nil
        self.savedSearchArticles = nil
        self.isSearching = false
        self.selectArticle(nil)
        self.mainTimelineViewController?.focus()
    }

    func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
        guard self.isSearching else { return }

        if searchString.count < 3 {
            setTimelineFeed(nil, animated: true)
            return
        }

        if searchString != self.lastSearchString || searchScope != self.lastSearchScope {
            switch searchScope {
            case .global:
                let searchPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
                setTimelineFeed(
                    SmartFeed(
                        identifier: "SearchFeedDelegate",
                        nameForDisplay: searchPrefix + searchString,
                        fetchType: .search(searchString),
                        smallIcon: Assets.Images.searchFeed
                    ),
                    animated: true
                )
            case .timeline:
                let searchPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
                setTimelineFeed(
                    SmartFeed(
                        identifier: "SearchTimelineFeedDelegate",
                        nameForDisplay: searchPrefix + searchString,
                        fetchType: .searchWithArticleIDs(searchString, self.savedSearchArticleIds!),
                        smallIcon: Assets.Images.searchFeed
                    ),
                    animated: true
                )
            }

            self.lastSearchString = searchString
            self.lastSearchScope = searchScope
        }
    }

    func saveReadFilterEnabledTableToUserDefaults() {
        AppDefaults.shared.sidebarItemsHidingReadArticles = self.sidebarItemsHidingReadArticles
    }
}
