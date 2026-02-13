//
//  ArticleFetcher.swift
//  Reed
//
//  Created by Brent Simmons on 2/4/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
protocol ArticleFetcher {
    func fetchArticles() throws -> Set<Article>
    func fetchArticlesAsync() async throws -> Set<Article>
    func fetchUnreadArticles() throws -> Set<Article>
    func fetchUnreadArticlesAsync() async throws -> Set<Article>
}

extension Feed: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        try dataStore?.fetchArticles(.feed(self)) ?? Set<Article>()
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected feed.dataStore, but got nil.")
            return Set<Article>()
        }
        return try await dataStore.fetchArticlesAsync(.feed(self))
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.fetchArticles().unreadArticles()
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected feed.dataStore, but got nil.")
            return Set<Article>()
        }
        // TODO: fetch only unread articles rather than filtering.
        let articles = try await dataStore.fetchArticlesAsync(.feed(self))
        return articles.unreadArticles()
    }
}

extension Folder: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected folder.dataStore, but got nil.")
            return Set<Article>()
        }
        return try dataStore.fetchArticles(.folder(self, false))
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected folder.dataStore, but got nil.")
            return Set<Article>()
        }
        return try await dataStore.fetchArticlesAsync(.folder(self, false))
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected folder.dataStore, but got nil.")
            return Set<Article>()
        }
        return try dataStore.fetchArticles(.folder(self, true))
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        guard let dataStore else {
            assertionFailure("Expected folder.dataStore, but got nil.")
            return Set<Article>()
        }
        return try await dataStore.fetchArticlesAsync(.folder(self, true))
    }
}
