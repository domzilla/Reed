//
//  IconImageCache.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 5/2/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
final class IconImageCache {
    static var shared = IconImageCache()

    private var smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
    private var feedIconImageCache = [SidebarItemIdentifier: IconImage]()
    private var faviconImageCache = [SidebarItemIdentifier: IconImage]()
    private var smallIconImageCache = [SidebarItemIdentifier: IconImage]()
    private var authorIconImageCache = [Author: IconImage]()

    func imageFor(_ feedID: SidebarItemIdentifier) -> IconImage? {
        if let smartFeed = SmartFeedsController.shared.find(by: feedID) {
            return self.imageForFeed(smartFeed)
        }
        if let feed = AccountManager.shared.existingFeed(with: feedID) {
            return self.imageForFeed(feed)
        }
        return nil
    }

    func imageForFeed(_ sidebarItem: SidebarItem) -> IconImage? {
        guard let sidebarItemID = sidebarItem.sidebarItemID else {
            return nil
        }

        if let smartFeed = sidebarItem as? PseudoFeed {
            return imageForSmartFeed(smartFeed, sidebarItemID)
        }
        if let feed = sidebarItem as? Feed, let iconImage = imageForFeed(feed, sidebarItemID) {
            return iconImage
        }
        if let smallIconProvider = sidebarItem as? SmallIconProvider {
            return imageForSmallIconProvider(smallIconProvider, sidebarItemID)
        }

        return nil
    }

    func imageForArticle(_ article: Article) -> IconImage? {
        if let iconImage = imageForAuthors(article.authors) {
            return iconImage
        }
        guard let feed = article.feed else {
            return nil
        }
        return self.imageForFeed(feed)
    }

    func emptyCache() {
        self.smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
        self.feedIconImageCache = [SidebarItemIdentifier: IconImage]()
        self.faviconImageCache = [SidebarItemIdentifier: IconImage]()
        self.smallIconImageCache = [SidebarItemIdentifier: IconImage]()
        self.authorIconImageCache = [Author: IconImage]()
    }
}

extension IconImageCache {
    private func imageForSmartFeed(_ smartFeed: PseudoFeed, _ feedID: SidebarItemIdentifier) -> IconImage? {
        if let iconImage = smartFeedIconImageCache[feedID] {
            return iconImage
        }
        if let iconImage = smartFeed.smallIcon {
            self.smartFeedIconImageCache[feedID] = iconImage
            return iconImage
        }
        return nil
    }

    private func imageForFeed(_ feed: Feed, _ feedID: SidebarItemIdentifier) -> IconImage? {
        if let iconImage = feedIconImageCache[feedID] {
            return iconImage
        }
        if let iconImage = FeedIconDownloader.shared.icon(for: feed) {
            self.feedIconImageCache[feedID] = iconImage
            return iconImage
        }
        if let faviconImage = faviconImageCache[feedID] {
            return faviconImage
        }
        if let faviconImage = FaviconDownloader.shared.faviconAsIcon(for: feed) {
            self.faviconImageCache[feedID] = faviconImage
            return faviconImage
        }
        return nil
    }

    private func imageForSmallIconProvider(
        _ provider: SmallIconProvider,
        _ feedID: SidebarItemIdentifier
    )
        -> IconImage?
    {
        if let iconImage = smallIconImageCache[feedID] {
            return iconImage
        }
        if let iconImage = provider.smallIcon {
            self.smallIconImageCache[feedID] = iconImage
            return iconImage
        }
        return nil
    }

    private func imageForAuthors(_ authors: Set<Author>?) -> IconImage? {
        guard let authors, authors.count == 1, let author = authors.first else {
            return nil
        }
        return self.imageForAuthor(author)
    }

    private func imageForAuthor(_ author: Author) -> IconImage? {
        if let iconImage = authorIconImageCache[author] {
            return iconImage
        }
        if let iconImage = AuthorAvatarDownloader.shared.image(for: author) {
            self.authorIconImageCache[author] = iconImage
            return iconImage
        }
        return nil
    }
}
