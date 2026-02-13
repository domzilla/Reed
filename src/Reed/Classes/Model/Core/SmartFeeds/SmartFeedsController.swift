//
//  SmartFeedsController.swift
//  Reed
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
final class SmartFeedsController: DisplayNameProvider, ContainerIdentifiable {
    nonisolated let containerID: ContainerIdentifier? = ContainerIdentifier.smartFeedController

    static let shared = SmartFeedsController()
    let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

    var smartFeeds = [SidebarItem]()

    let todayFeed = SmartFeed(
        identifier: "TodayFeedDelegate",
        nameForDisplay: NSLocalizedString("Today", comment: "Today pseudo-feed title"),
        fetchType: .today(nil),
        smallIcon: Assets.Images.todayFeed,
        unreadCountFetcher: { dataStore in
            try await dataStore.fetchUnreadCountForTodayAsync()
        }
    )

    let unreadFeed = UnreadFeed()

    let starredFeed = SmartFeed(
        identifier: "StarredFeedDelegate",
        nameForDisplay: NSLocalizedString("Starred", comment: "Starred pseudo-feed title"),
        fetchType: .starred(nil),
        smallIcon: Assets.Images.starredFeed,
        unreadCountFetcher: { dataStore in
            try await dataStore.fetchUnreadCountForStarredArticlesAsync()
        }
    )

    private init() {
        self.smartFeeds = [self.todayFeed, self.unreadFeed, self.starredFeed]
    }

    func find(by identifier: SidebarItemIdentifier) -> PseudoFeed? {
        switch identifier {
        case let .smartFeed(stringIdentifer):
            switch stringIdentifer {
            case "TodayFeedDelegate":
                self.todayFeed
            case String(describing: UnreadFeed.self):
                self.unreadFeed
            case "StarredFeedDelegate":
                self.starredFeed
            default:
                nil
            }
        default:
            nil
        }
    }
}
