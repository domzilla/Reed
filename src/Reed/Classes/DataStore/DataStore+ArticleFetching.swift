//
//  DataStore+ArticleFetching.swift
//  Reed
//
//  Extracted from DataStore.swift
//

import Foundation

// MARK: - Fetching Articles

extension DataStore {
    @MainActor
    func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
        switch fetchType {
        case let .starred(limit):
            try _fetchStarredArticles(limit: limit)
        case let .unread(limit):
            try _fetchUnreadArticles(limit: limit)
        case let .today(limit):
            try _fetchTodayArticles(limit: limit)
        case let .folder(folder, readFilter):
            if readFilter {
                try _fetchUnreadArticles(container: folder)
            } else {
                try _fetchArticles(container: folder)
            }
        case let .feed(feed):
            try _fetchArticles(feed: feed)
        case let .articleIDs(articleIDs):
            try _fetchArticles(articleIDs: articleIDs)
        case let .search(searchString):
            try _fetchArticlesMatching(searchString: searchString)
        case let .searchWithArticleIDs(searchString, articleIDs):
            try _fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
        }
    }

    @MainActor
    func fetchArticlesAsync(_ fetchType: FetchType) async throws -> Set<Article> {
        switch fetchType {
        case let .starred(limit):
            try await _fetchStarredArticlesAsync(limit: limit)
        case let .unread(limit):
            try await _fetchUnreadArticlesAsync(limit: limit)
        case let .today(limit):
            try await _fetchTodayArticlesAsync(limit: limit)
        case let .folder(folder, readFilter):
            if readFilter {
                try await _fetchUnreadArticlesAsync(container: folder)
            } else {
                try await _fetchArticlesAsync(container: folder)
            }
        case let .feed(feed):
            try await _fetchArticlesAsync(feed: feed)
        case let .articleIDs(articleIDs):
            try await _fetchArticlesAsync(articleIDs: articleIDs)
        case let .search(searchString):
            try await _fetchArticlesMatchingAsync(searchString: searchString)
        case let .searchWithArticleIDs(searchString, articleIDs):
            try await _fetchArticlesMatchingWithArticleIDsAsync(searchString: searchString, articleIDs: articleIDs)
        }
    }

    func fetchUnreadCountForStarredArticlesAsync() async throws -> Int? {
        try await self.database.fetchUnreadCountForStarredArticlesAsync(feedIDs: self.flattenedFeedsIDs)
    }

    func fetchCountForStarredArticles() throws -> Int {
        try self.database.fetchStarredArticlesCount(feedIDs: self.flattenedFeedsIDs)
    }

    func fetchUnreadCountForTodayAsync() async throws -> Int {
        try await self.database.fetchUnreadCountForTodayAsync(feedIDs: self.flattenedFeedsIDs)
    }

    func fetchUnreadArticleIDsAsync() async throws -> Set<String> {
        try await self.database.fetchUnreadArticleIDsAsync()
    }

    func fetchStarredArticleIDsAsync() async throws -> Set<String> {
        try await self.database.fetchStarredArticleIDsAsync()
    }

    /// Fetch articleIDs for articles that we should have, but don't. These articles are either (starred) or (newer than
    /// the article cutoff date).
    @MainActor
    func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync() async throws
        -> Set<String>
    {
        try await self.database.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
    }
}

// MARK: - Fetching Articles (Private)

@MainActor
extension DataStore {
    // MARK: - Starred Articles

    private func _fetchStarredArticles(limit: Int? = nil) throws -> Set<Article> {
        try self.database.fetchStarredArticles(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    private func _fetchStarredArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self.database.fetchedStarredArticlesAsync(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    // MARK: - Unread Articles

    private func _fetchUnreadArticles(limit: Int? = nil) throws -> Set<Article> {
        try self._fetchUnreadArticles(container: self, limit: limit)
    }

    private func _fetchUnreadArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self._fetchUnreadArticlesAsync(container: self, limit: limit)
    }

    // MARK: - Today Articles

    private func _fetchTodayArticles(limit: Int? = nil) throws -> Set<Article> {
        try self.database.fetchTodayArticles(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    private func _fetchTodayArticlesAsync(limit: Int? = nil) async throws -> Set<Article> {
        try await self.database.fetchTodayArticlesAsync(feedIDs: self.flattenedFeedsIDs, limit: limit)
    }

    // MARK: - Container Articles

    private func _fetchArticles(container: Container) throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try database.fetchArticles(feedIDs: feeds.feedIDs())
        self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        return articles
    }

    private func _fetchArticlesAsync(container: Container) async throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try await database.fetchArticlesAsync(feedIDs: feeds.feedIDs())
        self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        return articles
    }

    private func _fetchUnreadArticles(container: Container, limit: Int? = nil) throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try database.fetchUnreadArticles(feedIDs: feeds.feedIDs(), limit: limit)

        // We don't validate limit queries because they, by definition, won't correctly match the
        // complete unread state for the given container.
        if limit == nil {
            self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        }

        return articles
    }

    private func _fetchUnreadArticlesAsync(container: Container, limit: Int? = nil) async throws -> Set<Article> {
        let feeds = container.flattenedFeeds()
        let articles = try await database.fetchUnreadArticlesAsync(feedIDs: feeds.feedIDs(), limit: limit)

        // We don't validate limit queries because they, by definition, won't correctly match the
        // complete unread state for the given container.
        if limit == nil {
            self.validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
        }

        return articles
    }

    // MARK: - Feed Articles

    private func _fetchArticles(feed: Feed) throws -> Set<Article> {
        let articles = try database.fetchArticles(feedID: feed.feedID)
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    private func _fetchArticlesAsync(feed: Feed) async throws -> Set<Article> {
        let articles = try await database.fetchArticlesAsync(feedID: feed.feedID)
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    private func _fetchUnreadArticles(feed: Feed) throws -> Set<Article> {
        let articles = try database.fetchUnreadArticles(feedIDs: Set([feed.feedID]))
        self.validateUnreadCount(feed: feed, articles: articles)
        return articles
    }

    // MARK: - ArticleIDs Articles

    private func _fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
        try self.database.fetchArticles(articleIDs: articleIDs)
    }

    private func _fetchArticlesAsync(articleIDs: Set<String>) async throws -> Set<Article> {
        try await self.database.fetchArticlesAsync(articleIDs: articleIDs)
    }

    // MARK: - Search Articles

    func _fetchArticlesMatching(searchString: String) throws -> Set<Article> {
        try self.database.fetchArticlesMatching(searchString: searchString, feedIDs: self.flattenedFeedsIDs)
    }

    private func _fetchArticlesMatchingAsync(searchString: String) async throws -> Set<Article> {
        try await self.database.fetchArticlesMatchingAsync(searchString: searchString, feedIDs: self.flattenedFeedsIDs)
    }

    private func _fetchArticlesMatchingWithArticleIDs(
        searchString: String,
        articleIDs: Set<String>
    ) throws
        -> Set<Article>
    {
        try self.database.fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
    }

    private func _fetchArticlesMatchingWithArticleIDsAsync(
        searchString: String,
        articleIDs: Set<String>
    ) async throws
        -> Set<Article>
    {
        try await self.database.fetchArticlesMatchingWithArticleIDsAsync(
            searchString: searchString,
            articleIDs: articleIDs
        )
    }

    // MARK: - Validation

    private func validateUnreadCountsAfterFetchingUnreadArticles(feeds: Set<Feed>, articles: Set<Article>) {
        // Validate unread counts. This was the site of a performance slowdown:
        // it was calling going through the entire list of articles once per feed:
        // feeds.forEach { validateUnreadCount($0, articles) }
        // Now we loop through articles exactly once. This makes a huge difference.

        var unreadCountStorage = [String: Int]() // [FeedID: Int]
        for article in articles where !article.status.read {
            unreadCountStorage[article.feedID, default: 0] += 1
        }
        for feed in feeds {
            let unreadCount = unreadCountStorage[feed.feedID, default: 0]
            feed.unreadCount = unreadCount
        }
    }

    private func validateUnreadCount(feed: Feed, articles: Set<Article>) {
        // articles must contain all the unread articles for the feed.
        // The unread number should match the feed's unread count.
        var feedUnreadCount = 0
        for article in articles {
            if article.feed == feed, !article.status.read {
                feedUnreadCount += 1
            }
        }
        feed.unreadCount = feedUnreadCount
    }
}
