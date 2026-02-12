//
//  ParsedFeedTransformer.swift
//  RDParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
#endif

// RDRSSParser and RDAtomParser were written in Objective-C quite a while ago.
// They create an RDParsedFeed object and related Objective-C objects.
// These functions take an RDParsedFeed and return a Swift-y ParsedFeed,
// which is part of providing a single API for feed parsing.

enum ParsedFeedTransformer {
    static func parsedFeed(_ rsParsedFeed: RDParsedFeed) -> ParsedFeed {
        let items = parsedItems(rsParsedFeed.articles)
        return ParsedFeed(
            type: .rss,
            title: rsParsedFeed.title,
            homePageURL: rsParsedFeed.homepageURLString,
            feedURL: rsParsedFeed.urlString,
            language: rsParsedFeed.language,
            feedDescription: nil,
            nextURL: nil,
            iconURL: nil,
            faviconURL: nil,
            authors: nil,
            expired: false,
            hubs: nil,
            items: items
        )
    }
}

extension ParsedFeedTransformer {
    fileprivate static func parsedItems(_ parsedArticles: Set<RDParsedArticle>) -> Set<ParsedItem> {
        // Create Set<ParsedItem> from Set<RDParsedArticle>

        Set(parsedArticles.map(self.parsedItem))
    }

    fileprivate static func parsedItem(_ parsedArticle: RDParsedArticle) -> ParsedItem {
        let uniqueID = parsedArticle.articleID
        let url = parsedArticle.permalink
        let externalURL = parsedArticle.link
        let title = parsedArticle.title
        let language = parsedArticle.language
        let contentHTML = parsedArticle.body
        let markdown = parsedArticle.markdown
        let datePublished = parsedArticle.datePublished
        let dateModified = parsedArticle.dateModified
        let authors = self.parsedAuthors(parsedArticle.authors)
        let attachments = self.parsedAttachments(parsedArticle.enclosures)

        return ParsedItem(
            syncServiceID: nil,
            uniqueID: uniqueID,
            feedURL: parsedArticle.feedURL,
            url: url,
            externalURL: externalURL,
            title: title,
            language: language,
            contentHTML: contentHTML,
            contentText: nil,
            markdown: markdown,
            summary: nil,
            imageURL: nil,
            bannerImageURL: nil,
            datePublished: datePublished,
            dateModified: dateModified,
            authors: authors,
            tags: nil,
            attachments: attachments
        )
    }

    fileprivate static func parsedAuthors(_ authors: Set<RDParsedAuthor>?) -> Set<ParsedAuthor>? {
        guard let authors, !authors.isEmpty else {
            return nil
        }

        let transformedAuthors = authors.compactMap { author -> ParsedAuthor? in
            return ParsedAuthor(name: author.name, url: author.url, avatarURL: nil, emailAddress: author.emailAddress)
        }

        return transformedAuthors.isEmpty ? nil : Set(transformedAuthors)
    }

    fileprivate static func parsedAttachments(_ enclosures: Set<RDParsedEnclosure>?) -> Set<ParsedAttachment>? {
        guard let enclosures, !enclosures.isEmpty else {
            return nil
        }

        let attachments = enclosures.compactMap { enclosure -> ParsedAttachment? in
            let sizeInBytes = enclosure.length > 0 ? enclosure.length : nil
            return ParsedAttachment(
                url: enclosure.url,
                mimeType: enclosure.mimeType,
                title: nil,
                sizeInBytes: sizeInBytes,
                durationInSeconds: nil
            )
        }

        return attachments.isEmpty ? nil : Set(attachments)
    }
}
