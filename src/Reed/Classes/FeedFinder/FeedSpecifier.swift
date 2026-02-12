//
//  FeedSpecifier.swift
//  Reed
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedSpecifier: Sendable {
    enum Source: Int, Sendable {
        case UserEntered = 0, HTMLHead, HTMLLink

        func equalToOrBetterThan(_ otherSource: Source) -> Bool {
            self.rawValue <= otherSource.rawValue
        }
    }

    let title: String?
    let urlString: String
    let source: Source
    let orderFound: Int
    var score: Int {
        calculatedScore()
    }

    nonisolated init(title: String?, urlString: String, source: Source, orderFound: Int) {
        self.title = title
        self.urlString = urlString
        self.source = source
        self.orderFound = orderFound
    }

    /// Some feed URLs are known in advance. Save time/bandwidth by special-casing those.
    nonisolated static func knownFeedSpecifier(url: URL) -> FeedSpecifier? {
        if url.isRachelByTheBayURL {
            let feedURLString = "https://rachelbythebay.com/w/atom.xml"
            return FeedSpecifier(
                title: "writing - rachelbythebay",
                urlString: feedURLString,
                source: .UserEntered,
                orderFound: 0
            )
        }

        return nil
    }

    func feedSpecifierByMerging(_ feedSpecifier: FeedSpecifier) -> FeedSpecifier {
        // Take the best data (non-nil title, better source) to create a new feed specifier;

        let mergedTitle = self.title ?? feedSpecifier.title
        let mergedSource = self.source.equalToOrBetterThan(feedSpecifier.source) ? self.source : feedSpecifier.source
        let mergedOrderFound = self.orderFound < feedSpecifier.orderFound ? self.orderFound : feedSpecifier.orderFound

        return FeedSpecifier(
            title: mergedTitle,
            urlString: self.urlString,
            source: mergedSource,
            orderFound: mergedOrderFound
        )
    }

    nonisolated static func bestFeed(in feedSpecifiers: Set<FeedSpecifier>) -> FeedSpecifier? {
        if feedSpecifiers.isEmpty {
            return nil
        }
        if feedSpecifiers.count == 1 {
            return feedSpecifiers.first
        }

        var currentHighScore = Int.min
        var currentBestFeed: FeedSpecifier? = nil

        for oneFeedSpecifier in feedSpecifiers {
            let oneScore = oneFeedSpecifier.score
            if oneScore > currentHighScore {
                currentHighScore = oneScore
                currentBestFeed = oneFeedSpecifier
            }
        }

        return currentBestFeed
    }
}

// MARK: - Hashable

extension FeedSpecifier: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.urlString)
    }

    nonisolated static func == (lhs: FeedSpecifier, rhs: FeedSpecifier) -> Bool {
        lhs.urlString == rhs.urlString
    }
}

extension FeedSpecifier {
    private func calculatedScore() -> Int {
        var score = 0

        if self.source == .UserEntered {
            return 1000
        } else if self.source == .HTMLHead {
            score = score + 50
        }

        score = score - ((self.orderFound - 1) * 5)

        if self.urlString.caseInsensitiveContains("comments") {
            score = score - 10
        }
        if self.urlString.caseInsensitiveContains("podcast") {
            score = score - 10
        }
        if self.urlString.caseInsensitiveContains("rss") {
            score = score + 5
        }
        if self.urlString.hasSuffix("/index.xml") {
            score = score + 5
        }
        if self.urlString.hasSuffix("/feed/") {
            score = score + 5
        }
        if self.urlString.hasSuffix("/feed") {
            score = score + 4
        }
        if self.urlString.caseInsensitiveContains("json") {
            score = score + 3
        }

        if let title {
            if title.caseInsensitiveContains("comments") {
                score = score - 10
            }
        }

        return score
    }
}
