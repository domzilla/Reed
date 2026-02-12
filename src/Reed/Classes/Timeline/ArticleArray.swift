//
//  ArticleArray.swift
//  Reed
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

typealias ArticleArray = [Article]

@MainActor
extension [Article] {
    func articleAtRow(_ row: Int) -> Article? {
        if row < 0 || row == NSNotFound || row > count - 1 {
            return nil
        }
        return self[row]
    }

    func article(matching articleSpecifier: ArticleSpecifier) -> Article? {
        first { articleSpecifier.matchesArticle($0) }
    }

    func orderedRowIndexes(fromIndex startIndex: Int, wrappingToTop wrapping: Bool) -> [Int] {
        if startIndex >= self.count {
            // Wrap around to the top if specified
            wrapping ? [Int](0..<self.count) : []
        } else {
            // Start at the selection and wrap around to the beginning
            [Int](startIndex..<self.count) + (wrapping ? [Int](0..<startIndex) : [])
        }
    }

    func rowOfNextUnreadArticle(_ selectedRow: Int, wrappingToTop wrapping: Bool) -> Int? {
        if isEmpty {
            return nil
        }

        for rowIndex in self.orderedRowIndexes(fromIndex: selectedRow + 1, wrappingToTop: wrapping) {
            let article = self.articleAtRow(rowIndex)!
            if !article.status.read {
                return rowIndex
            }
        }

        return nil
    }

    func articlesForIndexes(_ indexes: IndexSet) -> [Article] {
        indexes.compactMap { oneIndex -> Article? in
            return self.articleAtRow(oneIndex)
        }
    }

    func sortedByDate(_ sortDirection: ComparisonResult, groupByFeed: Bool = false) -> ArticleArray {
        ArticleSorter.sortedByDate(articles: self, sortDirection: sortDirection, groupByFeed: groupByFeed)
    }

    func canMarkAllAsRead() -> Bool {
        self.anyArticleIsUnread()
    }

    func anyArticlePassesTest(_ test: (Article) -> Bool) -> Bool {
        for article in self {
            if test(article) {
                return true
            }
        }
        return false
    }

    func anyArticleIsReadAndCanMarkUnread() -> Bool {
        self.anyArticlePassesTest { $0.status.read && $0.isAvailableToMarkUnread }
    }

    func anyArticleIsUnread() -> Bool {
        self.anyArticlePassesTest { !$0.status.read }
    }

    func anyArticleIsStarred() -> Bool {
        self.anyArticlePassesTest { $0.status.starred }
    }

    func anyArticleIsUnstarred() -> Bool {
        self.anyArticlePassesTest { !$0.status.starred }
    }

    func unreadArticles() -> [Article]? {
        let articles = self.filter { !$0.status.read }
        return articles.isEmpty ? nil : articles
    }

    func representSameArticlesInSameOrder(as otherArticles: [Article]) -> Bool {
        if self.count != otherArticles.count {
            return false
        }
        var i = 0
        for article in self {
            let otherArticle = otherArticles[i]
            if article.dataStore != otherArticle.dataStore || article.articleID != otherArticle.articleID {
                return false
            }
            i += 1
        }
        return true
    }

    func articlesAbove(article: Article) -> [Article] {
        guard let position = firstIndex(of: article) else { return [] }
        return self.articlesAbove(position: position)
    }

    func articlesAbove(position: Int) -> [Article] {
        guard position < count else { return [] }
        let articlesAbove = self[..<position]
        return Array(articlesAbove)
    }

    func articlesBelow(article: Article) -> [Article] {
        guard let position = firstIndex(of: article) else { return [] }
        return self.articlesBelow(position: position)
    }

    func articlesBelow(position: Int) -> [Article] {
        guard position < count else { return [] }
        var articlesBelow = Array(self[position...])
        guard !articlesBelow.isEmpty else {
            return []
        }
        articlesBelow.removeFirst()
        return articlesBelow
    }
}
