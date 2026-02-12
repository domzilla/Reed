//
//  StarredFeedDelegate.swift
//  Reed
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
struct StarredFeedDelegate: SmartFeedDelegate {
    var sidebarItemID: SidebarItemIdentifier? {
        SidebarItemIdentifier.smartFeed(String(describing: StarredFeedDelegate.self))
    }

    let nameForDisplay = NSLocalizedString("Starred", comment: "Starred pseudo-feed title")
    let fetchType: FetchType = .starred(nil)
    var smallIcon: IconImage? {
        Assets.Images.starredFeed
    }

    func fetchUnreadCount(dataStore: DataStore) async throws -> Int? {
        try await dataStore.fetchUnreadCountForStarredArticlesAsync()
    }
}
