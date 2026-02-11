//
//  SmartFeedDelegate.swift
//  Reed
//
//  Created by Brent Simmons on 6/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
protocol SmartFeedDelegate: SidebarItemIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {
    var fetchType: FetchType { get }
    func fetchUnreadCount(account: Account) async throws -> Int?
}

@MainActor
extension SmartFeedDelegate {
    func fetchArticles() throws -> Set<Article> {
        try AccountManager.shared.fetchArticles(fetchType)
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await AccountManager.shared.fetchArticlesAsync(fetchType)
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.fetchArticles().unreadArticles()
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        let articles = try await fetchArticlesAsync()
        return articles.unreadArticles()
    }
}
