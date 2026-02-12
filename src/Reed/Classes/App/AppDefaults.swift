//
//  AppDefaults.swift
//  Reed
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import DZFoundation
import UIKit

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
    case automatic = 0
    case light = 1
    case dark = 2

    var description: String {
        switch self {
        case .automatic:
            NSLocalizedString("Automatic", comment: "Automatic")
        case .light:
            NSLocalizedString("Light", comment: "Light")
        case .dark:
            NSLocalizedString("Dark", comment: "Dark")
        }
    }
}

extension Notification.Name {
    static let userInterfaceColorPaletteDidUpdate = Notification
        .Name(rawValue: "UserInterfaceColorPaletteDidUpdateNotification")
}

final class AppDefaults: Sendable {
    static let shared = AppDefaults()
    static let defaultThemeName = "Default"

    private init() {}

    nonisolated(unsafe) static let store: UserDefaults = .init(suiteName: AppConstants.appGroup)!

    enum Key {
        static let userInterfaceColorPalette = "userInterfaceColorPalette"
        static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
        static let firstRunDate = "firstRunDate"
        static let timelineGroupByFeed = "timelineGroupByFeed"
        static let refreshClearsReadArticles = "refreshClearsReadArticles"
        static let timelineNumberOfLines = "timelineNumberOfLines"
        static let timelineIconDimension = "timelineIconSize"
        static let timelineSortDirection = "timelineSortDirection"
        static let articleFullscreenAvailable = "articleFullscreenAvailable"
        static let articleFullscreenEnabled = "articleFullscreenEnabled"
        static let lastRefresh = "lastRefresh"
        static let addFeedAccountID = "addFeedAccountID"
        static let addFeedFolderName = "addFeedFolderName"
        static let addFolderAccountID = "addFolderAccountID"
        static let refreshInterval = "refreshInterval"
        static let useSystemBrowser = "useSystemBrowser"
        static let currentThemeName = "currentThemeName"
        static let articleContentJavascriptEnabled = "articleContentJavascriptEnabled"
        static let hideReadFeeds = "hideReadFeeds"
        static let isShowingExtractedArticle = "isShowingExtractedArticle"
        static let articleWindowScrollY = "articleWindowScrollY"
        static let expandedContainers = "expandedContainers"
        static let sidebarItemsHidingReadArticles = "sidebarItemsHidingReadArticles"
        static let selectedSidebarItem = "selectedSidebarItem"
        static let selectedArticle = "selectedArticle"
        static let didMigrateLegacyStateRestorationInfo = "didMigrateLegacyStateRestorationInfo"
    }

    let isDeveloperBuild: Bool = {
        if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
            return true
        }
        return false
    }()

    let isFirstRun: Bool = {
        if let _ = AppDefaults.store.object(forKey: Key.firstRunDate) as? Date {
            return false
        }
        AppDefaults.firstRunDate = Date()
        return true
    }()

    static var userInterfaceColorPalette: UserInterfaceColorPalette {
        get {
            if let result = UserInterfaceColorPalette(rawValue: int(for: Key.userInterfaceColorPalette)) {
                return result
            }
            return .automatic
        }
        set {
            setInt(for: Key.userInterfaceColorPalette, newValue.rawValue)
            NotificationCenter.default.post(name: .userInterfaceColorPaletteDidUpdate, object: self)
        }
    }

    var addFeedAccountID: String? {
        get {
            AppDefaults.string(for: Key.addFeedAccountID)
        }
        set {
            AppDefaults.setString(for: Key.addFeedAccountID, newValue)
        }
    }

    var addFeedFolderName: String? {
        get {
            AppDefaults.string(for: Key.addFeedFolderName)
        }
        set {
            AppDefaults.setString(for: Key.addFeedFolderName, newValue)
        }
    }

    var addFolderAccountID: String? {
        get {
            AppDefaults.string(for: Key.addFolderAccountID)
        }
        set {
            AppDefaults.setString(for: Key.addFolderAccountID, newValue)
        }
    }

    var refreshInterval: RefreshInterval {
        get {
            let rawValue = AppDefaults.store.integer(forKey: Key.refreshInterval)
            return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
        }
        set {
            AppDefaults.store.set(newValue.rawValue, forKey: Key.refreshInterval)
        }
    }

    var useSystemBrowser: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.useSystemBrowser)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Key.useSystemBrowser)
        }
    }

    var lastImageCacheFlushDate: Date? {
        get {
            AppDefaults.date(for: Key.lastImageCacheFlushDate)
        }
        set {
            AppDefaults.setDate(for: Key.lastImageCacheFlushDate, newValue)
        }
    }

    var timelineGroupByFeed: Bool {
        get {
            AppDefaults.bool(for: Key.timelineGroupByFeed)
        }
        set {
            AppDefaults.setBool(for: Key.timelineGroupByFeed, newValue)
        }
    }

    var refreshClearsReadArticles: Bool {
        get {
            AppDefaults.bool(for: Key.refreshClearsReadArticles)
        }
        set {
            AppDefaults.setBool(for: Key.refreshClearsReadArticles, newValue)
        }
    }

    var timelineSortDirection: ComparisonResult {
        get {
            AppDefaults.sortDirection(for: Key.timelineSortDirection)
        }
        set {
            AppDefaults.setSortDirection(for: Key.timelineSortDirection, newValue)
        }
    }

    var articleFullscreenAvailable: Bool {
        get {
            AppDefaults.bool(for: Key.articleFullscreenAvailable)
        }
        set {
            AppDefaults.setBool(for: Key.articleFullscreenAvailable, newValue)
        }
    }

    var articleFullscreenEnabled: Bool {
        get {
            self.articleFullscreenAvailable && AppDefaults.bool(for: Key.articleFullscreenEnabled)
        }
        set {
            AppDefaults.setBool(for: Key.articleFullscreenEnabled, newValue)
        }
    }

    var logicalArticleFullscreenEnabled: Bool {
        self.articleFullscreenAvailable && self.articleFullscreenEnabled
    }

    var isArticleContentJavascriptEnabled: Bool {
        get {
            AppDefaults.bool(for: Key.articleContentJavascriptEnabled)
        }
        set {
            AppDefaults.setBool(for: Key.articleContentJavascriptEnabled, newValue)
        }
    }

    var lastRefresh: Date? {
        get {
            AppDefaults.date(for: Key.lastRefresh)
        }
        set {
            AppDefaults.setDate(for: Key.lastRefresh, newValue)
        }
    }

    var timelineNumberOfLines: Int {
        get {
            AppDefaults.int(for: Key.timelineNumberOfLines)
        }
        set {
            AppDefaults.setInt(for: Key.timelineNumberOfLines, newValue)
        }
    }

    var timelineIconSize: IconSize {
        get {
            let rawValue = AppDefaults.store.integer(forKey: Key.timelineIconDimension)
            return IconSize(rawValue: rawValue) ?? IconSize.medium
        }
        set {
            AppDefaults.store.set(newValue.rawValue, forKey: Key.timelineIconDimension)
        }
    }

    var currentThemeName: String? {
        get {
            AppDefaults.string(for: Key.currentThemeName)
        }
        set {
            AppDefaults.setString(for: Key.currentThemeName, newValue)
        }
    }

    var hideReadFeeds: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.hideReadFeeds)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.hideReadFeeds)
        }
    }

    var isShowingExtractedArticle: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.isShowingExtractedArticle)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isShowingExtractedArticle)
        }
    }

    var articleWindowScrollY: Int {
        get {
            UserDefaults.standard.integer(forKey: Key.articleWindowScrollY)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.articleWindowScrollY)
        }
    }

    var expandedContainers: Set<ContainerIdentifier> {
        get {
            guard
                let rawIdentifiers = UserDefaults.standard
                    .array(forKey: Key.expandedContainers) as? [[String: String]] else
            {
                return Set<ContainerIdentifier>()
            }
            let containerIdentifiers = rawIdentifiers.compactMap { ContainerIdentifier(userInfo: $0) }
            return Set(containerIdentifiers)
        }
        set {
            DZLog("AppDefaults: set expandedContainers: \(newValue)")
            let containerIdentifierUserInfos = newValue.compactMap(\.userInfo)
            UserDefaults.standard.set(containerIdentifierUserInfos, forKey: Key.expandedContainers)
        }
    }

    var sidebarItemsHidingReadArticles: Set<SidebarItemIdentifier> {
        get {
            guard
                let rawIdentifiers = UserDefaults.standard
                    .array(forKey: Key.sidebarItemsHidingReadArticles) as? [[String: String]] else
            {
                return Set<SidebarItemIdentifier>()
            }
            let feedIdentifiers = rawIdentifiers.compactMap { SidebarItemIdentifier(userInfo: $0) }
            return Set(feedIdentifiers)
        }
        set {
            let feedIdentifierUserInfos = newValue.compactMap(\.userInfo)
            UserDefaults.standard.set(feedIdentifierUserInfos, forKey: Key.sidebarItemsHidingReadArticles)
        }
    }

    var selectedSidebarItem: SidebarItemIdentifier? {
        get {
            guard let userInfo = UserDefaults.standard.dictionary(forKey: Key.selectedSidebarItem) as? [String: String] else {
                return nil
            }
            return SidebarItemIdentifier(userInfo: userInfo)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: Key.selectedSidebarItem)
                return
            }
            UserDefaults.standard.set(newValue.userInfo, forKey: Key.selectedSidebarItem)
        }
    }

    var selectedArticle: ArticleSpecifier? {
        get {
            guard let d = UserDefaults.standard.dictionary(forKey: Key.selectedArticle) as? [String: String] else {
                return nil
            }
            return ArticleSpecifier(dictionary: d)
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: Key.selectedArticle)
                return
            }
            UserDefaults.standard.set(newValue.dictionary, forKey: Key.selectedArticle)
        }
    }

    var didMigrateLegacyStateRestorationInfo: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.didMigrateLegacyStateRestorationInfo)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.didMigrateLegacyStateRestorationInfo)
        }
    }

    @MainActor
    static func registerDefaults() {
        let defaults: [String: Any] = [
            Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
            Key.timelineGroupByFeed: false,
            Key.refreshClearsReadArticles: false,
            Key.timelineNumberOfLines: 2,
            Key.timelineIconDimension: IconSize.medium.rawValue,
            Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
            Key.refreshInterval: RefreshInterval.everyHour.rawValue,
            Key.articleFullscreenAvailable: false,
            Key.articleFullscreenEnabled: false,
            Key.articleContentJavascriptEnabled: true,
            Key.currentThemeName: Self.defaultThemeName,
        ]
        AppDefaults.store.register(defaults: defaults)
    }
}

extension AppDefaults {
    fileprivate static var firstRunDate: Date? {
        get {
            date(for: Key.firstRunDate)
        }
        set {
            setDate(for: Key.firstRunDate, newValue)
        }
    }

    fileprivate static func string(for key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    fileprivate static func setString(for key: String, _ value: String?) {
        UserDefaults.standard.set(value, forKey: key)
    }

    fileprivate static func bool(for key: String) -> Bool {
        AppDefaults.store.bool(forKey: key)
    }

    fileprivate static func setBool(for key: String, _ flag: Bool) {
        AppDefaults.store.set(flag, forKey: key)
    }

    fileprivate static func int(for key: String) -> Int {
        AppDefaults.store.integer(forKey: key)
    }

    fileprivate static func setInt(for key: String, _ x: Int) {
        AppDefaults.store.set(x, forKey: key)
    }

    fileprivate static func date(for key: String) -> Date? {
        AppDefaults.store.object(forKey: key) as? Date
    }

    fileprivate static func setDate(for key: String, _ date: Date?) {
        AppDefaults.store.set(date, forKey: key)
    }

    fileprivate static func sortDirection(for key: String) -> ComparisonResult {
        let rawInt = self.int(for: key)
        if rawInt == ComparisonResult.orderedAscending.rawValue {
            return .orderedAscending
        }
        return .orderedDescending
    }

    fileprivate static func setSortDirection(for key: String, _ value: ComparisonResult) {
        if value == .orderedAscending {
            self.setInt(for: key, ComparisonResult.orderedAscending.rawValue)
        } else {
            self.setInt(for: key, ComparisonResult.orderedDescending.rawValue)
        }
    }
}

struct StateRestorationInfo {
    let hideReadFeeds: Bool
    let expandedContainers: Set<ContainerIdentifier>
    let selectedSidebarItem: SidebarItemIdentifier?
    let sidebarItemsHidingReadArticles: Set<SidebarItemIdentifier>
    let selectedArticle: ArticleSpecifier?
    let articleWindowScrollY: Int
    let isShowingExtractedArticle: Bool

    init(
        hideReadFeeds: Bool,
        expandedContainers: Set<ContainerIdentifier>,
        selectedSidebarItem: SidebarItemIdentifier?,
        sidebarItemsHidingReadArticles: Set<SidebarItemIdentifier>,
        selectedArticle: ArticleSpecifier?,
        articleWindowScrollY: Int,
        isShowingExtractedArticle: Bool
    ) {
        self.hideReadFeeds = hideReadFeeds
        self.expandedContainers = expandedContainers
        self.selectedSidebarItem = selectedSidebarItem
        self.sidebarItemsHidingReadArticles = sidebarItemsHidingReadArticles
        self.selectedArticle = selectedArticle
        self.articleWindowScrollY = articleWindowScrollY
        self.isShowingExtractedArticle = isShowingExtractedArticle

        // Break out interpolations to avoid OSLogMessage ambiguity.
        let expandedContainersDescription = String(describing: expandedContainers)
        let selectedSidebarItemUserInfo: [AnyHashable: AnyHashable] = selectedSidebarItem?.userInfo ?? [:]
        let sidebarItemsHidingDescription = String(describing: sidebarItemsHidingReadArticles)
        let selectedArticleDictionary: [String: String] = selectedArticle?.dictionary ?? [:]
        let isShowingExtractedArticleString = isShowingExtractedArticle ? "true" : "false"

        DZLog(
            "AppDefaults: StateRestorationInfo:\nexpandedContainers: \(expandedContainersDescription)\nselectedSidebarItem: \(selectedSidebarItemUserInfo)\nsidebarItemsHidingReadArticles: \(sidebarItemsHidingDescription)\nselectedArticle: \(selectedArticleDictionary)\narticleWindowScrollY: \(articleWindowScrollY)\nisShowingExtractedArticle: \(isShowingExtractedArticleString)"
        )
    }

    init() {
        self.init(
            hideReadFeeds: AppDefaults.shared.hideReadFeeds,
            expandedContainers: AppDefaults.shared.expandedContainers,
            selectedSidebarItem: AppDefaults.shared.selectedSidebarItem,
            sidebarItemsHidingReadArticles: AppDefaults.shared.sidebarItemsHidingReadArticles,
            selectedArticle: AppDefaults.shared.selectedArticle,
            articleWindowScrollY: AppDefaults.shared.articleWindowScrollY,
            isShowingExtractedArticle: AppDefaults.shared.isShowingExtractedArticle
        )
    }

    // TODO: Delete legacy state restoration migration.
    init(legacyState: NSUserActivity?) {
        if AppDefaults.shared.didMigrateLegacyStateRestorationInfo {
            self.init()
            return
        }

        AppDefaults.shared.didMigrateLegacyStateRestorationInfo = true

        // Extract legacy window state if available
        guard
            let windowState = legacyState?
                .userInfo?[AppConstants.StateRestorationKey.windowState] as? [AnyHashable: Any] else
        {
            self.init()
            return
        }

        let hideReadFeeds: Bool = if
            let legacyValue =
            windowState[AppConstants.StateRestorationKey.readFeedsFilterState] as? Bool
        {
            legacyValue
        } else {
            AppDefaults.shared.hideReadFeeds
        }

        let expandedContainers: Set<ContainerIdentifier>
        if
            let legacyState =
            windowState[AppConstants.StateRestorationKey
                .containerExpandedWindowState] as? [[AnyHashable: AnyHashable]]
        {
            let convertedState = legacyState.compactMap { dict -> [String: String]? in
                var stringDict = [String: String]()
                for (key, value) in dict {
                    if let keyString = key as? String, let valueString = value as? String {
                        stringDict[keyString] = valueString
                    }
                }
                return stringDict.isEmpty ? nil : stringDict
            }
            let containerIdentifiers = convertedState.compactMap { ContainerIdentifier(userInfo: $0) }
            expandedContainers = Set(containerIdentifiers)
        } else {
            expandedContainers = AppDefaults.shared.expandedContainers
        }

        let sidebarItemsHidingReadArticles: Set<SidebarItemIdentifier>
        if
            let legacyState =
            windowState[AppConstants.StateRestorationKey
                .readArticlesFilterState] as? [[AnyHashable: AnyHashable]: Bool]
        {
            let enabledFeeds = legacyState.filter { $0.value == true }
            let convertedState = enabledFeeds.keys.compactMap { key -> [String: String]? in
                var stringDict = [String: String]()
                for (k, v) in key {
                    if let keyString = k as? String, let valueString = v as? String {
                        stringDict[keyString] = valueString
                    }
                }
                return stringDict.isEmpty ? nil : stringDict
            }
            let feedIdentifiers = convertedState.compactMap { SidebarItemIdentifier(userInfo: $0) }
            sidebarItemsHidingReadArticles = Set(feedIdentifiers)
        } else {
            sidebarItemsHidingReadArticles = AppDefaults.shared.sidebarItemsHidingReadArticles
        }

        let selectedSidebarItem: SidebarItemIdentifier? = if
            let legacyState =
            (windowState[AppConstants.StateRestorationKey.sidebarItemID] ??
                windowState[AppConstants.StateRestorationKey.feedIdentifier]) as? [String: String],
            let feedIdentifier = SidebarItemIdentifier(userInfo: legacyState)
        {
            feedIdentifier
        } else {
            AppDefaults.shared.selectedSidebarItem
        }

        self.init(
            hideReadFeeds: hideReadFeeds,
            expandedContainers: expandedContainers,
            selectedSidebarItem: selectedSidebarItem,
            sidebarItemsHidingReadArticles: sidebarItemsHidingReadArticles,
            selectedArticle: AppDefaults.shared.selectedArticle,
            articleWindowScrollY: AppDefaults.shared.articleWindowScrollY,
            isShowingExtractedArticle: AppDefaults.shared.isShowingExtractedArticle
        )
    }
}
