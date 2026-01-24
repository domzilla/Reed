//
//  SearchTimelineFeedDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/31/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
struct SearchTimelineFeedDelegate: SmartFeedDelegate {
    var sidebarItemID: SidebarItemIdentifier? {
        SidebarItemIdentifier.smartFeed(String(describing: SearchTimelineFeedDelegate.self))
    }

    var nameForDisplay: String {
        self.nameForDisplayPrefix + self.searchString
    }

    let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
    let searchString: String
    let fetchType: FetchType
    var smallIcon: IconImage? = Assets.Images.searchFeed

    init(searchString: String, articleIDs: Set<String>) {
        self.searchString = searchString
        self.fetchType = .searchWithArticleIDs(searchString, articleIDs)
    }

    func fetchUnreadCount(account _: Account) async throws -> Int? {
        // TODO: after 5.0
        nil
    }
}
