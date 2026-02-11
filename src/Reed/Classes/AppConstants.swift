//
//  AppConstants.swift
//  Reed
//

import CloudKit

enum AppConstants {
    // MARK: - App Identifiers

    static let appGroup = SharedConstants.appGroup

    // MARK: - CloudKit

    static let cloudKitContainerIdentifier = "iCloud.net.domzilla.reed"
    static let cloudKitContainer = CKContainer(identifier: Self.cloudKitContainerIdentifier)

    // MARK: - Background Tasks

    static let backgroundFeedRefreshIdentifier = "net.domzilla.reed.FeedRefresh"

    // MARK: - Home Screen Shortcuts

    static let shortcutFirstUnread = "net.domzilla.reed.FirstUnread"
    static let shortcutShowSearch = "net.domzilla.reed.ShowSearch"
    static let shortcutShowAdd = "net.domzilla.reed.ShowAdd"

    // MARK: - Activity Types

    static let restorationActivityType = "net.domzilla.reed.restoration"
    static let findInArticleActivityType = "net.domzilla.reed.find"
    static let openInBrowserActivityType = "net.domzilla.reed.openInBrowser"

    // MARK: - Deep Links

    static let deepLinkScheme = "reed"
}
