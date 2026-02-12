//
//  DataExtensions.swift
//  Reed
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser

extension Notification.Name {
    public static let feedSettingDidChange = Notification.Name(rawValue: "FeedSettingDidChangeNotification")
}

extension Feed {
    public static let SettingUserInfoKey = "feedSetting"

    public enum SettingKey {
        public static let homePageURL = "homePageURL"
        public static let iconURL = "iconURL"
        public static let faviconURL = "faviconURL"
        public static let name = "name"
        public static let editedName = "editedName"
        public static let authors = "authors"
        public static let contentHash = "contentHash"
        public static let conditionalGetInfo = "conditionalGetInfo"
        public static let cacheControlInfo = "cacheControlInfo"
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
    @MainActor public var dataStore: DataStore? {
        DataStore.shared.existingDataStore(dataStoreID: accountID)
    }

    @MainActor public var feed: Feed? {
        self.dataStore?.existingFeed(withFeedID: feedID)
    }
}
