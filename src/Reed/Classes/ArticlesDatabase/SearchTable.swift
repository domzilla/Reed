//
//  SearchTable.swift
//  Reed
//
//  Created by Brent Simmons on 2/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Synchronization

final class ArticleSearchInfo: Hashable, Sendable {
    let articleID: String
    let title: String?
    let contentHTML: String?
    let contentText: String?
    let summary: String?
    let authorsNames: String?
    let searchRowID: Int?
    let bodyForIndex: String

    init(
        articleID: String,
        title: String?,
        contentHTML: String?,
        contentText: String?,
        summary: String?,
        authorsNames: String?,
        searchRowID: Int?
    ) {
        self.articleID = articleID
        self.title = title
        self.authorsNames = authorsNames
        self.contentHTML = contentHTML
        self.contentText = contentText
        self.summary = summary
        self.searchRowID = searchRowID

        let preferredText: String = {
            if let body = contentHTML, !body.isEmpty {
                return body
            }
            if let body = contentText, !body.isEmpty {
                return body
            }
            return summary ?? ""
        }()

        self.bodyForIndex = {
            let s = preferredText.rsparser_stringByDecodingHTMLEntities()
            let sanitizedBody = s.strippingHTML()

            if let authorsNames {
                return sanitizedBody.appending(" \(authorsNames)")
            } else {
                return sanitizedBody
            }
        }()
    }

    convenience init(article: Article) {
        let authorsNames: String? = if let authors = article.authors {
            authors.compactMap(\.name).joined(separator: " ")
        } else {
            nil
        }
        self.init(
            articleID: article.articleID,
            title: article.title,
            contentHTML: article.contentHTML,
            contentText: article.contentText,
            summary: article.summary,
            authorsNames: authorsNames,
            searchRowID: nil
        )
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.articleID)
    }

    // MARK: Equatable

    static func == (lhs: ArticleSearchInfo, rhs: ArticleSearchInfo) -> Bool {
        lhs.articleID == rhs.articleID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs
            .contentText == rhs.contentText && lhs.summary == rhs.summary && lhs.authorsNames == rhs.authorsNames && lhs
            .searchRowID == rhs.searchRowID
    }
}

final class SearchTable: DatabaseTable, @unchecked Sendable {
    let name = "search"
    private let queue: DatabaseQueue
    weak var articlesTable: ArticlesTable?

    init(queue: DatabaseQueue) {
        self.queue = queue
    }

    func ensureIndexedArticles(for articleIDs: Set<String>) {
        guard !articleIDs.isEmpty else {
            return
        }
        self.queue.runInTransaction { databaseResult in
            if let database = databaseResult.database {
                self.ensureIndexedArticles(articleIDs, database)
            }
        }
    }

    /// Add to, or update, the search index for articles with specified IDs.
    func ensureIndexedArticles(_ articleIDs: Set<String>, _ database: FMDatabase) {
        guard let articlesTable else {
            return
        }
        guard let articleSearchInfos = articlesTable.fetchArticleSearchInfos(articleIDs, in: database) else {
            return
        }

        let unindexedArticles = articleSearchInfos.filter { $0.searchRowID == nil }
        performInitialIndexForArticles(unindexedArticles, database)

        let indexedArticles = articleSearchInfos.filter { $0.searchRowID != nil }
        updateIndexForArticles(indexedArticles, database)
    }

    /// Index new articles.
    func indexNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {
        let articleSearchInfos = Set(articles.map { ArticleSearchInfo(article: $0) })
        performInitialIndexForArticles(articleSearchInfos, database)
    }

    /// Index updated articles.
    func indexUpdatedArticles(_ articles: Set<Article>, _ database: FMDatabase) {
        self.ensureIndexedArticles(articles.articleIDs(), database)
    }
}

// MARK: - Private

extension SearchTable {
    private func performInitialIndexForArticles(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) {
        articles.forEach { self.performInitialIndex($0, database) }
    }

    private func performInitialIndex(_ article: ArticleSearchInfo, _ database: FMDatabase) {
        let rowid = self.insert(article, database)
        self.articlesTable?.updateRowsWithValue(
            rowid,
            valueKey: DatabaseKey.searchRowID,
            whereKey: DatabaseKey.articleID,
            matches: [article.articleID],
            database: database
        )
    }

    private func insert(_ article: ArticleSearchInfo, _ database: FMDatabase) -> Int {
        let rowDictionary: DatabaseDictionary = [
            DatabaseKey.body: article.bodyForIndex,
            DatabaseKey.title: article.title ?? "",
        ]
        insertRow(rowDictionary, insertType: .normal, in: database)
        return Int(database.lastInsertRowId())
    }

    private struct SearchInfo: Hashable {
        let rowID: Int
        let title: String
        let body: String

        init(row: FMResultSet) {
            self.rowID = Int(row.longLongInt(forColumn: DatabaseKey.rowID))
            self.title = row.string(forColumn: DatabaseKey.title) ?? ""
            self.body = row.string(forColumn: DatabaseKey.body) ?? ""
        }

        // MARK: Hashable

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.rowID)
        }
    }

    private func updateIndexForArticles(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) {
        if articles.isEmpty {
            return
        }
        guard let searchInfos = fetchSearchInfos(articles, database) else {
            // The articles that get here have a non-nil searchRowID, and we should have found rows in the search table
            // for them.
            // But we didn’t. Recover by doing an initial index.
            self.performInitialIndexForArticles(articles, database)
            return
        }
        let groupedSearchInfos = Dictionary(grouping: searchInfos, by: { $0.rowID })
        let searchInfosDictionary = groupedSearchInfos.mapValues { $0.first! }

        for article in articles {
            self.updateIndexForArticle(article, searchInfosDictionary, database)
        }
    }

    private func updateIndexForArticle(
        _ article: ArticleSearchInfo,
        _ searchInfosDictionary: [Int: SearchInfo],
        _ database: FMDatabase
    ) {
        guard let searchRowID = article.searchRowID else {
            assertionFailure("Expected article.searchRowID, got nil")
            return
        }
        guard let searchInfo: SearchInfo = searchInfosDictionary[searchRowID] else {
            // Shouldn’t happen. The article has a searchRowID, but we didn’t find that row in the search table.
            // Easy to recover from: just do an initial index, and all’s well.
            self.performInitialIndex(article, database)
            return
        }

        let title = article.title ?? ""
        if title == searchInfo.title, article.bodyForIndex == searchInfo.body {
            return
        }

        var updateDictionary = DatabaseDictionary()
        if title != searchInfo.title {
            updateDictionary[DatabaseKey.title] = title
        }
        if article.bodyForIndex != searchInfo.body {
            updateDictionary[DatabaseKey.body] = article.bodyForIndex
        }
        updateRowsWithDictionary(
            updateDictionary,
            whereKey: DatabaseKey.rowID,
            matches: searchInfo.rowID,
            database: database
        )
    }

    private func fetchSearchInfos(_ articles: Set<ArticleSearchInfo>, _ database: FMDatabase) -> Set<SearchInfo>? {
        let searchRowIDs = articles.compactMap(\.searchRowID)
        guard !searchRowIDs.isEmpty else {
            return nil
        }
        let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(searchRowIDs.count))!
        let sql = "select rowid, title, body from \(name) where rowid in \(placeholders);"
        guard let resultSet = database.executeQuery(sql, withArgumentsIn: searchRowIDs) else {
            return nil
        }
        return resultSet.mapToSet { SearchInfo(row: $0) }
    }
}
