//
//  SingleArticleFetcher.swift
//  Account
//
//  Created by Maurice Parker on 11/29/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct SingleArticleFetcher: ArticleFetcher {
    private let dataStore: DataStore
    private let articleID: String

    public init(dataStore: DataStore, articleID: String) {
        self.dataStore = dataStore
        self.articleID = articleID
    }

    public func fetchArticles() throws -> Set<Article> {
        try self.dataStore.fetchArticles(.articleIDs(Set([self.articleID])))
    }

    public func fetchArticlesAsync() async throws -> Set<Article> {
        try await self.dataStore.fetchArticlesAsync(.articleIDs(Set([self.articleID])))
    }

    public func fetchUnreadArticles() throws -> Set<Article> {
        try self.dataStore.fetchArticles(.articleIDs(Set([self.articleID])))
    }

    public func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        try await self.dataStore.fetchArticlesAsync(.articleIDs(Set([self.articleID])))
    }
}
