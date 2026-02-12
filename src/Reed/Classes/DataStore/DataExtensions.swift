//
//  DataExtensions.swift
//  Reed
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let feedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

extension Feed {
    static let SettingUserInfoKey = "feedSetting"

    enum SettingKey {
        static let homePageURL = "homePageURL"
        static let iconURL = "iconURL"
        static let faviconURL = "faviconURL"
        static let name = "name"
        static let editedName = "editedName"
        static let authors = "authors"
        static let contentHash = "contentHash"
        static let conditionalGetInfo = "conditionalGetInfo"
        static let cacheControlInfo = "cacheControlInfo"
    }
}

extension Feed {
    @MainActor
    func takeSettings(from parsedFeed: ParsedFeed) {
        iconURL = parsedFeed.iconURL
        faviconURL = parsedFeed.faviconURL
        homePageURL = parsedFeed.homePageURL
        name = parsedFeed.title
        authors = Author.authorsWithParsedAuthors(parsedFeed.authors)
    }

    func postFeedSettingDidChangeNotification(_ codingKey: FeedMetadata.CodingKeys) {
        let userInfo = [Feed.SettingUserInfoKey: codingKey.stringValue]
        NotificationCenter.default.post(name: .feedSettingDidChange, object: self, userInfo: userInfo)
    }
}

extension Article {
    @MainActor var dataStore: DataStore? {
        DataStore.shared.existingDataStore(dataStoreID: accountID)
    }

    @MainActor var feed: Feed? {
        self.dataStore?.existingFeed(withFeedID: feedID)
    }
}
