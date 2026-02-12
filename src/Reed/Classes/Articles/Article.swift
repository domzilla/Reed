//
//  Article.swift
//  Reed
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

typealias ArticleSetBlock = (Set<Article>) -> Void

final class Article: Sendable {
    let articleID: String // Unique database ID (possibly sync service ID)
    let accountID: String
    let feedID: String // Likely a URL, but not necessarily
    let uniqueID: String // Unique per feed (RSS guid, for example)
    let title: String?
    let contentHTML: String?
    let contentText: String?
    let markdown: String?
    let rawLink: String? // We store raw source value, but use computed url or link other than where raw value
    // required.
    let rawExternalLink: String? // We store raw source value, but use computed externalURL or externalLink other
    // than where raw value required.
    let summary: String?
    let rawImageLink: String? // We store raw source value, but use computed imageURL or imageLink other than
    // where raw value required.
    let datePublished: Date?
    let dateModified: Date?
    let authors: Set<Author>?
    let status: ArticleStatus

    init(
        accountID: String,
        articleID: String?,
        feedID: String,
        uniqueID: String,
        title: String?,
        contentHTML: String?,
        contentText: String?,
        markdown: String?,
        url: String?,
        externalURL: String?,
        summary: String?,
        imageURL: String?,
        datePublished: Date?,
        dateModified: Date?,
        authors: Set<Author>?,
        status: ArticleStatus
    ) {
        self.accountID = accountID
        self.feedID = feedID
        self.uniqueID = uniqueID
        self.title = title
        self.contentHTML = contentHTML
        self.contentText = contentText
        self.markdown = markdown
        self.rawLink = url
        self.rawExternalLink = externalURL
        self.summary = summary
        self.rawImageLink = imageURL
        self.datePublished = datePublished
        self.dateModified = dateModified
        self.authors = authors
        self.status = status

        if let articleID {
            self.articleID = articleID
        } else {
            self.articleID = Article.calculatedArticleID(feedID: feedID, uniqueID: uniqueID)
        }
    }

    static func calculatedArticleID(feedID: String, uniqueID: String) -> String {
        databaseIDWithString("\(feedID) \(uniqueID)")
    }
}

// MARK: - Hashable

extension Article: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.articleID)
    }

    nonisolated static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.articleID == rhs.articleID && lhs.accountID == rhs.accountID && lhs.feedID == rhs.feedID && lhs
            .uniqueID == rhs.uniqueID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs
            .contentText == rhs.contentText && lhs.rawLink == rhs.rawLink && lhs.rawExternalLink == rhs
            .rawExternalLink && lhs.summary == rhs.summary && lhs.rawImageLink == rhs.rawImageLink && lhs
            .datePublished == rhs.datePublished && lhs.dateModified == rhs.dateModified && lhs.authors == rhs.authors
    }
}

extension Set<Article> {
    nonisolated func articleIDs() -> Set<String> {
        Set<String>(map(\.articleID))
    }

    nonisolated func unreadArticles() -> Set<Article> {
        let articles = self.filter { !$0.status.read }
        return Set(articles)
    }

    nonisolated func contains(accountID: String, articleID: String) -> Bool {
        self.contains(where: { $0.accountID == accountID && $0.articleID == articleID })
    }
}

extension [Article] {
    nonisolated func articleIDs() -> [String] {
        map(\.articleID)
    }
}

extension Article {
    private static let allowedTags: Set = [
        "b",
        "bdi",
        "bdo",
        "cite",
        "code",
        "del",
        "dfn",
        "em",
        "i",
        "ins",
        "kbd",
        "mark",
        "q",
        "s",
        "samp",
        "small",
        "strong",
        "sub",
        "sup",
        "time",
        "u",
        "var",
    ]

    func sanitizedTitle(forHTML: Bool = true) -> String? {
        guard let title else {
            return nil
        }

        let scanner = Scanner(string: title)
        scanner.charactersToBeSkipped = nil
        var result = ""
        result.reserveCapacity(title.count)

        while !scanner.isAtEnd {
            if let text = scanner.scanUpToString("<") {
                result.append(text)
            }

            if let _ = scanner.scanString("<") {
                // All the allowed tags currently don't allow attributes
                if let tag = scanner.scanUpToString(">") {
                    if Self.allowedTags.contains(tag.replacingOccurrences(of: "/", with: "")) {
                        forHTML ? result.append("<\(tag)>") : result.append("")
                    } else {
                        forHTML ? result.append("&lt;\(tag)&gt;") : result.append("<\(tag)>")
                    }

                    _ = scanner.scanString(">")
                }
            }
        }

        return result
    }
}
