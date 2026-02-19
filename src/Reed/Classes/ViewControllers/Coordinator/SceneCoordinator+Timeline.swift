//
//  SceneCoordinator+Timeline.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func selectArticle(
        _ article: Article?,
        animations: Animations = [],
        isShowingExtractedArticle _: Bool? = nil,
        articleWindowScrollY: Int? = nil
    ) {
        guard article != self.currentArticle else { return }

        self.currentArticle = article

        if article == nil {
            self.articleViewController?.article = nil
            self.rootSplitViewController.show(.supplementary)
            self.mainTimelineViewController?.updateArticleSelection(animations: animations)
            return
        }

        self.rootSplitViewController.show(.secondary)

        // Mark article as read before navigating to it, so the read status does not flash unread/read on display
        markArticles(Set([article!]), statusKey: .read, flag: true)

        self.mainTimelineViewController?.updateArticleSelection(animations: animations)
        self.articleViewController?.article = article
        if let articleWindowScrollY {
            self.articleViewController?.restoreScrollPosition = articleWindowScrollY
        }
    }

    func findPrevArticle(_ article: Article) -> Article? {
        guard let index = articles.firstIndex(of: article), index > 0 else {
            return nil
        }
        return self.articles[index - 1]
    }

    func findNextArticle(_ article: Article) -> Article? {
        guard let index = articles.firstIndex(of: article), index + 1 != articles.count else {
            return nil
        }
        return self.articles[index + 1]
    }

    func selectPrevArticle() {
        if let article = prevArticle {
            self.selectArticle(article, animations: [.navigation, .scroll])
        }
    }

    func selectNextArticle() {
        if let article = nextArticle {
            self.selectArticle(article, animations: [.navigation, .scroll])
        }
    }

    func selectFirstUnread() {
        self.selectFirstUnreadArticleInTimeline()
    }

    func selectPrevUnread() {
        // This should never happen, but I don't want to risk throwing us
        // into an infinite loop searching for an unread that isn't there.
        if appDelegate.unreadCount < 1 {
            return
        }

        self.isNavigationDisabled = true
        defer {
            isNavigationDisabled = false
        }

        if self.selectPrevUnreadArticleInTimeline() {
            return
        }

        self.selectPrevUnreadFeedFetcher()
        self.selectPrevUnreadArticleInTimeline()
    }

    func selectNextUnread() {
        // This should never happen, but I don't want to risk throwing us
        // into an infinite loop searching for an unread that isn't there.
        if appDelegate.unreadCount < 1 {
            return
        }

        self.isNavigationDisabled = true
        defer {
            isNavigationDisabled = false
        }

        if self.selectNextUnreadArticleInTimeline() {
            return
        }

        if self.isSearching {
            self.mainTimelineViewController?.hideSearch()
        }

        self.selectNextUnreadFeed {
            self.selectNextUnreadArticleInTimeline()
        }
    }

    func scrollOrGoToNextUnread() {
        if self.articleViewController?.canScrollDown() ?? false {
            self.articleViewController?.scrollPageDown()
        } else {
            self.selectNextUnread()
        }
    }

    func scrollUp() {
        if self.articleViewController?.canScrollUp() ?? false {
            self.articleViewController?.scrollPageUp()
        }
    }

    func selectArticleInCurrentFeed(
        _ articleID: String,
        isShowingExtractedArticle: Bool? = nil,
        articleWindowScrollY: Int? = nil
    ) {
        if let article = self.articles.first(where: { $0.articleID == articleID }) {
            self.selectArticle(
                article,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
        }
    }

    // MARK: - Timeline Feed

    func setTimelineFeed(_ sidebarItem: SidebarItem?, animated: Bool, completion: (() -> Void)? = nil) {
        self.timelineFeed = sidebarItem

        self.fetchAndReplaceArticlesAsync(animated: animated) {
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: true)
            completion?()
        }
    }

    // MARK: - Unread Navigation (Previous)

    @discardableResult
    func selectPrevUnreadArticleInTimeline() -> Bool {
        let startingRow: Int = if let articleRow = currentArticleRow {
            articleRow
        } else {
            self.articles.count - 1
        }

        return self.selectPrevArticleInTimeline(startingRow: startingRow)
    }

    private func selectPrevArticleInTimeline(startingRow: Int) -> Bool {
        guard startingRow >= 0 else {
            return false
        }

        for i in (0...startingRow).reversed() {
            let article = self.articles[i]
            if !article.status.read {
                self.selectArticle(article)
                return true
            }
        }

        return false
    }

    private func selectPrevUnreadFeedFetcher() {
        let indexPath: IndexPath = if self.currentFeedIndexPath == nil {
            IndexPath(row: 0, section: 0)
        } else {
            self.currentFeedIndexPath!
        }

        // Increment or wrap around the IndexPath
        let nextIndexPath = if indexPath.row - 1 < 0 {
            if indexPath.section - 1 < 0 {
                IndexPath(
                    row: self.shadowTable[self.shadowTable.count - 1].feedNodes.count - 1,
                    section: self.shadowTable.count - 1
                )
            } else {
                IndexPath(
                    row: self.shadowTable[indexPath.section - 1].feedNodes.count - 1,
                    section: indexPath.section - 1
                )
            }
        } else {
            IndexPath(row: indexPath.row - 1, section: indexPath.section)
        }

        if self.selectPrevUnreadFeedFetcher(startingWith: nextIndexPath) {
            return
        }
        let maxIndexPath = IndexPath(
            row: shadowTable[shadowTable.count - 1].feedNodes.count - 1,
            section: self.shadowTable.count - 1
        )
        self.selectPrevUnreadFeedFetcher(startingWith: maxIndexPath)
    }

    @discardableResult
    private func selectPrevUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
        for i in (0...indexPath.section).reversed() {
            let startingRow: Int = if indexPath.section == i {
                indexPath.row
            } else {
                self.shadowTable[i].feedNodes.count - 1
            }

            for j in (0...startingRow).reversed() {
                let prevIndexPath = IndexPath(row: j, section: i)
                guard
                    let node = nodeFor(prevIndexPath),
                    let unreadCountProvider = node.representedObject as? UnreadCountProvider else
                {
                    assertionFailure()
                    return true
                }

                if self.isExpanded(node) {
                    continue
                }

                if unreadCountProvider.unreadCount > 0 {
                    self.selectFeed(indexPath: prevIndexPath, animations: [.scroll, .navigation])
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Unread Navigation (Next)

    @discardableResult
    func selectFirstUnreadArticleInTimeline() -> Bool {
        self.selectNextArticleInTimeline(startingRow: 0, animated: true)
    }

    @discardableResult
    private func selectNextUnreadArticleInTimeline() -> Bool {
        let startingRow: Int = if let articleRow = currentArticleRow {
            articleRow + 1
        } else {
            0
        }

        return self.selectNextArticleInTimeline(startingRow: startingRow, animated: false)
    }

    private func selectNextArticleInTimeline(startingRow: Int, animated _: Bool) -> Bool {
        guard startingRow < self.articles.count else {
            return false
        }

        for i in startingRow..<self.articles.count {
            let article = self.articles[i]
            if !article.status.read {
                self.selectArticle(article, animations: [.scroll, .navigation])
                return true
            }
        }

        return false
    }

    private func selectNextUnreadFeed(completion: @escaping () -> Void) {
        let indexPath: IndexPath = if self.currentFeedIndexPath == nil {
            IndexPath(row: -1, section: 0)
        } else {
            self.currentFeedIndexPath!
        }

        // Increment or wrap around the IndexPath
        let nextIndexPath = if indexPath.row + 1 >= self.shadowTable[indexPath.section].feedNodes.count {
            if indexPath.section + 1 >= self.shadowTable.count {
                IndexPath(row: 0, section: 0)
            } else {
                IndexPath(row: 0, section: indexPath.section + 1)
            }
        } else {
            IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }

        self.selectNextUnreadFeed(startingWith: nextIndexPath) { found in
            if !found {
                self.selectNextUnreadFeed(startingWith: IndexPath(row: 0, section: 0)) { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
    }

    private func selectNextUnreadFeed(startingWith indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        for i in indexPath.section..<self.shadowTable.count {
            let startingRow: Int = if indexPath.section == i {
                indexPath.row
            } else {
                0
            }

            for j in startingRow..<self.shadowTable[i].feedNodes.count {
                let nextIndexPath = IndexPath(row: j, section: i)
                guard
                    let node = nodeFor(nextIndexPath),
                    let unreadCountProvider = node.representedObject as? UnreadCountProvider else
                {
                    assertionFailure()
                    completion(false)
                    return
                }

                if self.isExpanded(node) {
                    continue
                }

                if unreadCountProvider.unreadCount > 0 {
                    self.selectFeed(
                        indexPath: nextIndexPath,
                        animations: [.scroll, .navigation],
                        deselectArticle: false
                    ) {
                        self.currentArticle = nil
                        completion(true)
                    }
                    return
                }
            }
        }

        completion(false)
    }

    // MARK: - Article Fetching

    func emptyTheTimeline() {
        if !self.articles.isEmpty {
            self.replaceArticles(with: Set<Article>(), animated: false)
        }
    }

    func queueFetchAndMergeArticles() {
        self.fetchAndMergeArticlesQueue.add(self, #selector(self.fetchAndMergeArticlesAsyncObjc))
    }

    @objc
    func fetchAndMergeArticlesAsyncObjc() {
        self.fetchAndMergeArticlesAsync(animated: true) {
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: false)
            self.mainTimelineViewController?.restoreSelectionIfNecessary(adjustScroll: false)
        }
    }

    func fetchAndMergeArticlesAsync(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let timelineFeed else {
            return
        }

        self.fetchUnsortedArticlesAsync(for: [timelineFeed]) { [weak self] unsortedArticles in
            // Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
            guard let strongSelf = self else {
                return
            }
            let unsortedArticleIDs = unsortedArticles.articleIDs()
            var updatedArticles = unsortedArticles
            for article in strongSelf.articles {
                if !unsortedArticleIDs.contains(article.articleID) {
                    updatedArticles.insert(article)
                }
                if article.dataStore?.existingFeed(withFeedID: article.feedID) == nil {
                    updatedArticles.remove(article)
                }
            }

            strongSelf.replaceArticles(with: updatedArticles, animated: animated)
            completion?()
        }
    }

    func cancelPendingAsyncFetches() {
        self.fetchSerialNumber += 1
        self.fetchRequestQueue.cancelAllRequests()
    }

    func fetchAndReplaceArticlesAsync(animated: Bool, completion: @escaping () -> Void) {
        // To be called when we need to do an entire fetch, but an async delay is okay.
        // Example: we have the Today feed selected, and the calendar day just changed.
        self.cancelPendingAsyncFetches()
        guard let timelineFeed else {
            self.emptyTheTimeline()
            completion()
            return
        }

        var fetchers = [ArticleFetcher]()
        fetchers.append(timelineFeed)
        if self.exceptionArticleFetcher != nil {
            fetchers.append(self.exceptionArticleFetcher!)
            self.exceptionArticleFetcher = nil
        }

        self.fetchUnsortedArticlesAsync(for: fetchers) { [weak self] articles in
            self?.replaceArticles(with: articles, animated: animated)
            completion()
        }
    }

    func fetchUnsortedArticlesAsync(for representedObjects: [Any], completion: @escaping ArticleSetBlock) {
        // The callback will *not* be called if the fetch is no longer relevant — that is,
        // if it's been superseded by a newer fetch, or the timeline was emptied, etc., it won't get called.
        precondition(Thread.isMainThread)
        self.cancelPendingAsyncFetches()

        let fetchers = representedObjects.compactMap { $0 as? ArticleFetcher }
        let fetchSerialNumber = self.fetchSerialNumber

        self.fetchRequestQueue.fetchArticles(
            using: fetchers,
            isReadFiltered: self.isReadFeedsFiltered
        ) { [weak self] articles in
            guard let self, fetchSerialNumber == self.fetchSerialNumber else { return }
            completion(articles)
        }
    }

    func timelineFetcherContainsAnyPseudoFeed() -> Bool {
        if self.timelineFeed is PseudoFeed {
            return true
        }
        return false
    }

    func timelineFetcherContainsAnyFolder() -> Bool {
        if self.timelineFeed is Folder {
            return true
        }
        return false
    }

    func timelineFetcherContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
        // Return true if there's a match or if a folder contains (recursively) one of feeds

        if let feed = timelineFeed as? Feed {
            for oneFeed in feeds {
                if feed.feedID == oneFeed.feedID || feed.url == oneFeed.url {
                    return true
                }
            }
        } else if let folder = timelineFeed as? Folder {
            for oneFeed in feeds {
                if folder.hasFeed(with: oneFeed.feedID) || folder.hasFeed(withURL: oneFeed.url) {
                    return true
                }
            }
        }

        return false
    }
}
