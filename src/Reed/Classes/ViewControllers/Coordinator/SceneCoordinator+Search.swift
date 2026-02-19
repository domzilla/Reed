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
        let newValue = !self.isReadFeedsFiltered
        self.treeControllerDelegate.isReadFiltered = newValue
        AppDefaults.shared.hideReadFeeds = newValue
        rebuildBackingStores()
        self.mainFeedCollectionViewController?.updateUI()
        self.refreshTimeline(resetScroll: false)
    }

    func toggleReadArticlesFilter() {
        self.toggleReadFeedsFilter()
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
}
