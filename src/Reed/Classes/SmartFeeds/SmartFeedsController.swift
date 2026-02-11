//
//  SmartFeedsController.swift
//  Reed
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
final class SmartFeedsController: DisplayNameProvider, ContainerIdentifiable {
    nonisolated let containerID: ContainerIdentifier? = ContainerIdentifier.smartFeedController

    static let shared = SmartFeedsController()
    let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

    var smartFeeds = [SidebarItem]()
    let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
    let unreadFeed = UnreadFeed()
    let starredFeed = SmartFeed(delegate: StarredFeedDelegate())

    private init() {
        self.smartFeeds = [self.todayFeed, self.unreadFeed, self.starredFeed]
    }

    func find(by identifier: SidebarItemIdentifier) -> PseudoFeed? {
        switch identifier {
        case let .smartFeed(stringIdentifer):
            switch stringIdentifer {
            case String(describing: TodayFeedDelegate.self):
                self.todayFeed
            case String(describing: UnreadFeed.self):
                self.unreadFeed
            case String(describing: StarredFeedDelegate.self):
                self.starredFeed
            default:
                nil
            }
        default:
            nil
        }
    }
}
