//
//  LocalAccountRefresher.swift
//  Reed
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import RSParser
import RSWeb

@MainActor
protocol LocalAccountRefresherDelegate {
    func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges)
}

@MainActor
final class LocalAccountRefresher {
    var delegate: LocalAccountRefresherDelegate?
    var downloadProgress: DownloadProgress {
        self.downloadSession.downloadProgress
    }

    private var completion: (() -> Void)?
    private var isSuspended = false

    private lazy var downloadSession: DownloadSession = .init(delegate: self)

    private var urlToFeedDictionary = [String: Feed]()

    @MainActor
    func refreshFeeds(_ feeds: Set<Feed>) async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.refreshFeeds(feeds) {
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func refreshFeeds(_ feeds: Set<Feed>, completion: (() -> Void)? = nil) {
        let specialCaseCutoffDate = Date().bySubtracting(hours: 25)
        let filteredFeeds = feeds.filter { !Self.feedShouldBeSkipped($0, specialCaseCutoffDate) }

        guard !filteredFeeds.isEmpty else {
            Task { @MainActor in
                completion?()
            }
            return
        }

        self.urlToFeedDictionary.removeAll()
        for feed in filteredFeeds {
            self.urlToFeedDictionary[feed.url] = feed
        }

        let urls = filteredFeeds.compactMap { Self.url(for: $0) }

        self.completion = completion
        self.downloadSession.download(Set(urls))
    }

    @MainActor
    func suspend() {
        self.downloadSession.cancelAll()
        self.isSuspended = true
    }

    @MainActor
    func resume() {
        self.isSuspended = false
    }
}

// MARK: - DownloadSessionDelegate

@MainActor
extension LocalAccountRefresher: DownloadSessionDelegate {
    func downloadSession(_: DownloadSession, conditionalGetInfoFor url: URL) -> HTTPConditionalGetInfo? {
        guard let feed = urlToFeedDictionary[url.absoluteString] else {
            assertionFailure("LocalAccountRefresher: expected feed for \(url)")
            DZLog("LocalAccountRefresher: expected feed for \(url)")
            return nil
        }
        guard let conditionalGetInfo = feed.conditionalGetInfo else {
            DZLog("LocalAccountRefresher: no conditional GET info for \(url)")
            return nil
        }

        // Conditional GET info is dropped every 8 days, because some servers just always
        // respond with a 304 when *any* conditional GET info is sent, which means
        // those feeds don’t get updated. By dropping conditional GET info periodically,
        // we make sure those feeds get updated.
        if let conditionalGetInfoDate = feed.conditionalGetInfoDate {
            let eightDaysAgo = Date().bySubtracting(days: 8)
            if conditionalGetInfoDate < eightDaysAgo {
                if
                    !SpecialCase.urlStringContainSpecialCase(
                        url.absoluteString,
                        [SpecialCase.openRSSOrgHostName, SpecialCase.rachelByTheBayHostName]
                    )
                {
                    DZLog("LocalAccountRefresher: dropping conditional GET info for \(url) — more than 8 days old")
                    feed.conditionalGetInfo = nil
                    return nil
                }
            }
        }

        return conditionalGetInfo
    }

    func downloadSession(
        _: DownloadSession,
        downloadDidComplete url: URL,
        response: URLResponse?,
        data: Data,
        error: NSError?
    ) {
        guard let feed = urlToFeedDictionary[url.absoluteString] else {
            return
        }
        feed.lastCheckDate = Date()

        guard error == nil else {
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        let statusIsOK = httpResponse.statusIsOK
        let statusIsOKOrNotModified = statusIsOK || httpResponse.statusCode == HTTPResponseCode.notModified
        guard statusIsOKOrNotModified else {
            return
        }

        let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
        if conditionalGetInfo != feed.conditionalGetInfo {
            DZLog("LocalAccountRefresher: setting conditionalGetInfo for \(url.absoluteString)")
            feed.conditionalGetInfo = conditionalGetInfo
        }

        guard statusIsOK else {
            return
        }

        if url.isOpenRSSOrgURL {
            // Supported only for openrss.org. Cache-Control headers are
            // otherwise not intentional for feeds, unfortunately.
            if let cacheControlInfo = CacheControlInfo(urlResponse: httpResponse) {
                feed.cacheControlInfo = cacheControlInfo
            }
        }

        let dataHash = data.md5String
        if dataHash == feed.contentHash {
            return
        }

        Task { @MainActor in
            DZLog("LocalAccountRefresher: parsing feed for \(url.absoluteString)")

            let parserData = ParserData(url: feed.url, data: data)
            guard let parsedFeed = try? await FeedParser.parse(parserData) else {
                return
            }
            guard let account = feed.account else {
                return
            }

            assert(Thread.isMainThread)
            guard let articleChanges = try? await account.updateAsync(feed: feed, parsedFeed: parsedFeed) else {
                return
            }

            DZLog("LocalAccountRefresher: setting contentHash for \(url.absoluteString)")
            feed.contentHash = dataHash

            self.delegate?.localAccountRefresher(self, articleChanges: articleChanges)
        }
    }

    func downloadSession(_: DownloadSession, shouldContinueAfterReceivingData data: Data, url _: URL) -> Bool {
        guard !data.isDefinitelyNotFeed(), !self.isSuspended else {
            return false
        }
        return true
    }

    func downloadSessionDidComplete(_: DownloadSession) {
        Task { @MainActor in
            self.completion?()
            self.completion = nil
        }
    }
}

// MARK: - Private

extension LocalAccountRefresher {
    /// These hosts will never return a feed.
    ///
    /// People may still have feeds pointing to Twitter due to our prior
    /// use of the Twitter API. (Which Twitter took away.)
    fileprivate static let badHosts = ["twitter.com", "www.twitter.com", "x.com", "www.x.com"]

    /// Return true if we won’t download that feed.
    fileprivate static func feedIsDisallowed(_ feed: Feed) -> Bool {
        guard let url = url(for: feed) else {
            return true
        }
        guard let lowercaseHost = url.host()?.lowercased() else {
            return true
        }

        for badHost in self.badHosts {
            if lowercaseHost == badHost {
                DZLog(
                    "LocalAccountRefresher: Dropping request becasue it’s X/Twitter, which doesn’t provide feeds: \(feed.url)"
                )
                return true
            }
        }

        return false
    }

    fileprivate static func feedShouldBeSkipped(_ feed: Feed, _ specialCaseCutoffDate: Date) -> Bool {
        self.feedShouldBeSkippedForCacheControlReasons(feed) ||
            self.feedIsDisallowed(feed) ||
            self.feedShouldBeSkippedForTimingReasons(feed, specialCaseCutoffDate)
    }

    fileprivate static func feedShouldBeSkippedForTimingReasons(_ feed: Feed, _ specialCaseCutoffDate: Date) -> Bool {
        guard let lastCheckDate = feed.lastCheckDate else {
            return false
        }

        if
            SpecialCase.urlStringContainSpecialCase(
                feed.url,
                [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]
            )
        {
            if lastCheckDate > specialCaseCutoffDate {
                DZLog("LocalAccountRefresher: Dropping request for special case timing reasons: \(feed.url)")
                return true
            }
        }

        return false
    }

    fileprivate static func feedShouldBeSkippedForCacheControlReasons(_ feed: Feed) -> Bool {
        // We support Cache-Control only for openrss.org. The rest of the feed-providing
        // universe hasn’t dealt with Cache-Control, and we routinely see days-long
        // max-ages for even fast-moving feeds.
        //
        // However, openrss.org does make sure their Cache-Control headers are
        // intentional, and we should honor those.
        if SpecialCase.urlStringContainSpecialCase(feed.url, [SpecialCase.openRSSOrgHostName]) {
            if let cacheControlInfo = feed.cacheControlInfo, !cacheControlInfo.canResume {
                DZLog("LocalAccountRefresher: Dropping request for special case Cache-Control reasons: \(feed.url)")
                return true
            }
        }

        return false
    }

    fileprivate static var urlCache = [String: URL]()

    fileprivate static func url(for feed: Feed) -> URL? {
        assert(Thread.isMainThread)

        let urlString = feed.url

        if let url = urlCache[urlString] {
            return url
        }
        if let url = URL(string: urlString) {
            self.urlCache[urlString] = url
            return url
        }

        return nil
    }
}

// MARK: - Utility

extension Data {
    fileprivate func isDefinitelyNotFeed() -> Bool {
        // We only detect a few image types for now. This should get fleshed-out at some later date.
        self.isImage
    }
}
