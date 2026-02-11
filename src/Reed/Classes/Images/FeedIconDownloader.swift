//
//  FeedIconDownloader.swift
//  Reed
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import RSWeb

extension Notification.Name {
    static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable") // UserInfoKey.feed
}

@MainActor
public final class FeedIconDownloader {
    public static let shared = FeedIconDownloader()

    private let imageDownloader = ImageDownloader.shared
    private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)
    private var homePagesWithNoIconURL = Set<String>()
    private var cache = [Feed: IconImage]()
    private var waitingForFeedURLs = [String: Feed]()

    private var feedURLToIconURLCache = [String: String]()
    private var feedURLToIconURLCachePath: URL
    private var feedURLToIconURLCacheDirty = false {
        didSet {
            queueSaveFeedURLToIconURLCacheIfNeeded()
        }
    }

    init() {
        let folder = AppConfig.cacheSubfolder(named: "FeedIcons")
        self.feedURLToIconURLCachePath = folder.appendingPathComponent("FeedURLToIconURLCache.plist")
        loadFeedURLToIconURLCache()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.imageDidBecomeAvailable(_:)),
            name: .imageDidBecomeAvailable,
            object: self.imageDownloader
        )
    }

    func icon(for feed: Feed) -> IconImage? {
        if let cachedImage = cache[feed] {
            return cachedImage
        }

        if Self.shouldSkipDownloadingFeedIcon(feed: feed) {
            return nil
        }

        @MainActor
        func checkHomePageURL() {
            guard let homePageURL = feed.homePageURL else {
                return
            }
            if self.homePagesWithNoIconURL.contains(homePageURL) {
                return
            }
            self.icon(forHomePageURL: homePageURL, feed: feed) { image, iconURL in
                if let image, let iconURL {
                    self.cache[feed] = IconImage(image)
                    self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
                    self.postFeedIconDidBecomeAvailableNotification(feed)
                }
            }
        }

        @MainActor
        func checkFeedIconURL() {
            if let iconURL = feed.iconURL {
                self.icon(forURL: iconURL, feed: feed) { image in
                    Task { @MainActor in
                        if let image {
                            self.cache[feed] = IconImage(image)
                            self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
                            self.postFeedIconDidBecomeAvailableNotification(feed)
                        } else {
                            checkHomePageURL()
                        }
                    }
                }
            } else {
                checkHomePageURL()
            }
        }

        if let previouslyFoundIconURL = feedURLToIconURLCache[feed.url] {
            self.icon(forURL: previouslyFoundIconURL, feed: feed) { image in
                MainActor.assumeIsolated {
                    if let image {
                        self.postFeedIconDidBecomeAvailableNotification(feed)
                        self.cache[feed] = IconImage(image)
                    }
                }
            }

            return nil
        }

        checkFeedIconURL()

        return nil
    }

    @objc
    func imageDidBecomeAvailable(_ note: Notification) {
        guard let url = note.userInfo?[UserInfoKey.url] as? String, let feed = waitingForFeedURLs[url] else {
            return
        }
        self.waitingForFeedURLs[url] = nil
        _ = self.icon(for: feed)
    }
}

extension FeedIconDownloader {
    fileprivate static let specialCasesToSkip = [
        "macsparky.com",
        "xkcd.com",
        SpecialCase.rachelByTheBayHostName,
        SpecialCase.openRSSOrgHostName,
    ]

    fileprivate static func shouldSkipDownloadingFeedIcon(feed: Feed) -> Bool {
        self.shouldSkipDownloadingFeedIcon(feed.url)
    }

    fileprivate static func shouldSkipDownloadingFeedIcon(_ urlString: String) -> Bool {
        SpecialCase.urlStringContainSpecialCase(urlString, self.specialCasesToSkip)
    }

    private func icon(
        forHomePageURL homePageURL: String,
        feed: Feed,
        _ resultBlock: @escaping @MainActor (UIImage?, String?) -> Void
    ) {
        if Self.shouldSkipDownloadingFeedIcon(homePageURL) {
            resultBlock(nil, nil)
            return
        }

        if self.homePagesWithNoIconURL.contains(homePageURL) {
            resultBlock(nil, nil)
            return
        }

        guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
            resultBlock(nil, nil)
            return
        }

        if let url = metadata.bestWebsiteIconURL() {
            self.homePagesWithNoIconURL.remove(homePageURL)
            self.icon(forURL: url, feed: feed) { image in
                Task { @MainActor in
                    resultBlock(image, url)
                }
            }
            return
        }

        self.homePagesWithNoIconURL.insert(homePageURL)
        resultBlock(nil, nil)
    }

    private func icon(forURL url: String, feed: Feed, _ imageResultBlock: @escaping ImageResultBlock) {
        self.waitingForFeedURLs[url] = feed
        guard let imageData = imageDownloader.image(for: url) else {
            imageResultBlock(nil)
            return
        }
        UIImage.scaledForIcon(imageData, imageResultBlock: imageResultBlock)
    }

    private func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {
        DispatchQueue.main.async {
            let userInfo: [AnyHashable: Any] = [UserInfoKey.feed: feed]
            NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
        }
    }

    private func cacheIconURLForFeedURL(iconURL: String, feedURL: String) {
        self.feedURLToIconURLCache[feedURL] = iconURL
        self.feedURLToIconURLCacheDirty = true
    }

    private func loadFeedURLToIconURLCache() {
        guard let data = try? Data(contentsOf: feedURLToIconURLCachePath) else {
            return
        }
        let decoder = PropertyListDecoder()
        self.feedURLToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
    }

    @objc
    private func saveFeedURLToIconURLCacheIfNeeded() {
        assert(Thread.isMainThread)
        if self.feedURLToIconURLCacheDirty {
            self.saveFeedURLToIconURLCache()
        }
    }

    private func queueSaveFeedURLToIconURLCacheIfNeeded() {
        assert(Thread.isMainThread)
        FeedIconDownloader.saveQueue.add(self, #selector(self.saveFeedURLToIconURLCacheIfNeeded))
    }

    private func saveFeedURLToIconURLCache() {
        self.feedURLToIconURLCacheDirty = false

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            let data = try encoder.encode(self.feedURLToIconURLCache)
            try data.write(to: self.feedURLToIconURLCachePath)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}
