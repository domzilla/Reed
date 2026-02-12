//
//  ParsedFeed.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ParsedFeed: Sendable {
    let type: FeedType
    let title: String?
    let homePageURL: String?
    let feedURL: String?
    let language: String?
    let feedDescription: String?
    let nextURL: String?
    let iconURL: String?
    let faviconURL: String?
    let authors: Set<ParsedAuthor>?
    let expired: Bool
    let hubs: Set<ParsedHub>?
    let items: Set<ParsedItem>

    init(
        type: FeedType,
        title: String?,
        homePageURL: String?,
        feedURL: String?,
        language: String?,
        feedDescription: String?,
        nextURL: String?,
        iconURL: String?,
        faviconURL: String?,
        authors: Set<ParsedAuthor>?,
        expired: Bool,
        hubs: Set<ParsedHub>?,
        items: Set<ParsedItem>
    ) {
        self.type = type
        self.title = title
        self.homePageURL = homePageURL?.nilIfEmptyOrWhitespace
        self.feedURL = feedURL
        self.language = language
        self.feedDescription = feedDescription
        self.nextURL = nextURL
        self.iconURL = iconURL
        self.faviconURL = faviconURL
        self.authors = authors
        self.expired = expired
        self.hubs = hubs
        self.items = items
    }
}
