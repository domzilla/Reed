//
//  ArticleUtilities.swift
//  Reed
//
//  Created by Brent Simmons on 7/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
func markArticles(
    _ articles: Set<Article>,
    statusKey: ArticleStatus.Key,
    flag: Bool,
    completion: (() -> Void)? = nil
) {
    DataStore.shared.markArticles(articles, statusKey: statusKey, flag: flag) { _ in
        completion?()
    }
}

@MainActor
extension Article {
    var url: URL? {
        URL.encodeSpacesIfNeeded(rawLink)
    }

    var externalURL: URL? {
        URL.encodeSpacesIfNeeded(rawExternalLink)
    }

    var imageURL: URL? {
        URL.encodeSpacesIfNeeded(rawImageLink)
    }

    var link: String? {
        // Prefer link from URL, if one can be created, as these are repaired if required.
        // Provide the raw link if URL creation fails.
        self.url?.absoluteString ?? rawLink
    }

    var externalLink: String? {
        // Prefer link from externalURL, if one can be created, as these are repaired if required.
        // Provide the raw link if URL creation fails.
        self.externalURL?.absoluteString ?? rawExternalLink
    }

    var imageLink: String? {
        // Prefer link from imageURL, if one can be created, as these are repaired if required.
        // Provide the raw link if URL creation fails.
        self.imageURL?.absoluteString ?? rawImageLink
    }

    var preferredLink: String? {
        if let link, !link.isEmpty {
            return link
        }
        if let externalLink, !externalLink.isEmpty {
            return externalLink
        }
        return nil
    }

    var preferredURL: URL? {
        self.url ?? self.externalURL
    }

    var body: String? {
        contentHTML ?? contentText ?? summary
    }

    var logicalDatePublished: Date {
        datePublished ?? dateModified ?? status.dateArrived
    }

    var isAvailableToMarkUnread: Bool {
        true
    }

    func iconImage() -> IconImage? {
        IconImageCache.shared.imageForArticle(self)
    }

    func iconImageUrl(feed: Feed) -> URL? {
        if let image = iconImage() {
            let fm = FileManager.default
            var path = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let feedID = feed.feedID.replacingOccurrences(of: "/", with: "_")
            path.appendPathComponent(feedID + "_smallIcon.png")
            fm.createFile(atPath: path.path, contents: image.image.dataRepresentation()!, attributes: nil)
            return path
        } else {
            return nil
        }
    }

    func byline() -> String {
        guard let authors = authors ?? feed?.authors, !authors.isEmpty else {
            return ""
        }

        // If the author's name is the same as the feed, then we don't want to display it.
        // This code assumes that multiple authors would never match the feed name so that
        // if there feed owner has an article co-author all authors are given the byline.
        if authors.count == 1, let author = authors.first {
            if author.name == feed?.nameForDisplay {
                return ""
            }
        }

        var byline = ""
        var isFirstAuthor = true

        for author in authors {
            if !isFirstAuthor {
                byline += ", "
            }
            isFirstAuthor = false

            var authorEmailAddress: String? = nil
            if
                let emailAddress = author.emailAddress,
                !(emailAddress.contains("noreply@") || emailAddress.contains("no-reply@"))
            {
                authorEmailAddress = emailAddress
            }

            if let emailAddress = authorEmailAddress, emailAddress.contains(" ") {
                byline += emailAddress // probably name plus email address
            } else if let name = author.name, let emailAddress = authorEmailAddress {
                byline += "\(name) <\(emailAddress)>"
            } else if let name = author.name {
                byline += name
            } else if let emailAddress = authorEmailAddress {
                byline += "<\(emailAddress)>"
            } else if let url = author.url {
                byline += url
            }
        }

        return byline
    }
}

// MARK: Path

enum ArticlePathKey {
    static let dataStoreID = "accountID"
    static let dataStoreName = "accountName"
    static let feedID = "feedID"
    static let articleID = "articleID"
}

@MainActor
extension Article {
    var pathUserInfo: [AnyHashable: Any] {
        [
            ArticlePathKey.dataStoreID: accountID,
            ArticlePathKey.dataStoreName: dataStore?.nameForDisplay ?? "",
            ArticlePathKey.feedID: feedID,
            ArticlePathKey.articleID: articleID,
        ]
    }
}

// MARK: SortableArticle

@MainActor
extension Article: SortableArticle {
    var sortableName: String {
        feed?.name ?? ""
    }

    var sortableDate: Date {
        self.logicalDatePublished
    }

    var sortableArticleID: String {
        articleID
    }

    var sortableFeedID: String {
        feedID
    }
}
