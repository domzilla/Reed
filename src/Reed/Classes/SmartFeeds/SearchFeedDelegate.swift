//
//  SearchFeedDelegate.swift
//  Reed
//
//  Created by Brent Simmons on 2/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
struct SearchFeedDelegate: SmartFeedDelegate {
    var sidebarItemID: SidebarItemIdentifier? {
        SidebarItemIdentifier.smartFeed(String(describing: SearchFeedDelegate.self))
    }

    var nameForDisplay: String {
        self.nameForDisplayPrefix + self.searchString
    }

    let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
    let searchString: String
    let fetchType: FetchType
    var smallIcon: IconImage? = Assets.Images.searchFeed

    init(searchString: String) {
        self.searchString = searchString
        self.fetchType = .search(searchString)
    }

    func fetchUnreadCount(account _: Account) async throws -> Int? {
        // TODO: after 5.0
        nil
    }
}
