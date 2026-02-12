//
//  ParsedItem.swift
//  RDParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Markdown

struct ParsedItem: Hashable, Sendable {
    let syncServiceID: String? // Nil when not syncing
    let uniqueID: String // RSS guid, for instance; may be calculated
    let feedURL: String
    let url: String?
    let externalURL: String?
    let title: String?
    let language: String?
    let contentHTML: String?
    let contentText: String?
    let markdown: String?
    let summary: String?
    let imageURL: String?
    let bannerImageURL: String?
    let datePublished: Date?
    let dateModified: Date?
    let authors: Set<ParsedAuthor>?
    let tags: Set<String>?
    let attachments: Set<ParsedAttachment>?

    init(
        syncServiceID: String?,
        uniqueID: String,
        feedURL: String,
        url: String?,
        externalURL: String?,
        title: String?,
        language: String?,
        contentHTML: String?,
        contentText: String?,
        markdown: String?,
        summary: String?,
        imageURL: String?,
        bannerImageURL: String?,
        datePublished: Date?,
        dateModified: Date?,
        authors: Set<ParsedAuthor>?,
        tags: Set<String>?,
        attachments: Set<ParsedAttachment>?
    ) {
        self.syncServiceID = syncServiceID
        self.uniqueID = uniqueID
        self.feedURL = feedURL
        self.url = url
        self.externalURL = externalURL
        self.title = title
        self.language = language
        self.contentText = contentText
        self.markdown = markdown
        self.summary = summary
        self.imageURL = imageURL
        self.bannerImageURL = bannerImageURL
        self.datePublished = datePublished
        self.dateModified = dateModified
        self.authors = authors
        self.tags = tags
        self.attachments = attachments

        // Render Markdown when present, else use contentHTML
        if let markdown {
            self.contentHTML = HTMLFormatter.format(Document(parsing: markdown))
        } else {
            self.contentHTML = contentHTML
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        if let syncServiceID {
            hasher.combine(syncServiceID)
        } else {
            hasher.combine(self.uniqueID)
            hasher.combine(self.feedURL)
        }
    }
}
