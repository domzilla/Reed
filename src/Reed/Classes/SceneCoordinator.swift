//
//  SceneCoordinator.swift
//  Reed
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
import RSTree
import SafariServices
import UIKit
import UserNotifications

enum SearchScope: Int {
    case timeline = 0
    case global = 1
}

enum ShowFeedName {
    case none
    case byline
    case feed
}

struct FeedNode: Hashable, Sendable {
    let node: Node
    let sidebarItemID: SidebarItemIdentifier

    @MainActor
    init(_ node: Node) {
        self.node = node
        self.sidebarItemID = (node.representedObject as! SidebarItem).sidebarItemID!
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.sidebarItemID)
    }
}

@MainActor
final class SceneCoordinator: NSObject, UndoableCommandRunner {
    var undoableCommands = [UndoableCommand]()
    var undoManager: UndoManager? {
        self.rootSplitViewController.undoManager
    }

    lazy var webViewProvider = WebViewProvider(coordinator: self)

    private var rootSplitViewController: RootSplitViewController!

    private var mainFeedCollectionViewController: MainFeedCollectionViewController!
    private var mainTimelineViewController: MainTimelineViewController?
    private var articleViewController: ArticleViewController?

    private let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
    private let rebuildBackingStoresQueue = CoalescingQueue(name: "Rebuild The Backing Stores", interval: 0.5)
    private var fetchSerialNumber = 0
    private let fetchRequestQueue = FetchRequestQueue()

    // Which Containers are expanded
    private var expandedContainers = Set<ContainerIdentifier>()

    // Which Containers used to be expanded. Reset by rebuilding the Shadow Table.
    private var lastExpandedContainers = Set<ContainerIdentifier>()

    // Which SidebarItems have the Read Articles Filter enabled
    private var sidebarItemsHidingReadArticles = Set<SidebarItemIdentifier>()
    private var readFilterEnabledTable: [SidebarItemIdentifier: Bool] { // TODO: remove this
        var d = [SidebarItemIdentifier: Bool]()
        for sidebarItemIdentifier in self.sidebarItemsHidingReadArticles {
            d[sidebarItemIdentifier] = true
        }
        return d
    }

    // Flattened tree structure for the Sidebar
    private var shadowTable = [(sectionID: String, feedNodes: [FeedNode])]()

    private(set) var preSearchTimelineFeed: SidebarItem?
    private var lastSearchString = ""
    private var lastSearchScope: SearchScope?
    private var isSearching: Bool = false
    private var savedSearchArticles: ArticleArray?
    private var savedSearchArticleIds: Set<String>?

    var isTimelineViewControllerPending = false
    var isArticleViewControllerPending = false

    /// `Bool` to track whether a refresh is scheduled.
    private var isNavigationBarSubtitleRefreshScheduled: Bool = false

    private(set) var sortDirection = AppDefaults.shared.timelineSortDirection {
        didSet {
            if self.sortDirection != oldValue {
                sortParametersDidChange()
            }
        }
    }

    private(set) var groupByFeed = AppDefaults.shared.timelineGroupByFeed {
        didSet {
            if self.groupByFeed != oldValue {
                sortParametersDidChange()
            }
        }
    }

    var prefersStatusBarHidden = false

    private let treeControllerDelegate = SidebarTreeControllerDelegate()
    private let treeController: TreeController

    var stateRestorationActivity: NSUserActivity {
        let activity = NSUserActivity(activityType: AppConstants.restorationActivityType)
        activity.persistentIdentifier = UUID().uuidString
        return activity
    }

    var isNavigationDisabled = false

    var isRootSplitCollapsed: Bool {
        self.rootSplitViewController.isCollapsed
    }

    var isReadFeedsFiltered: Bool {
        self.treeControllerDelegate.isReadFiltered
    }

    var isReadArticlesFiltered: Bool {
        if let sidebarItemID = timelineFeed?.sidebarItemID {
            return self.sidebarItemsHidingReadArticles.contains(sidebarItemID)
        }
        return self.timelineDefaultReadFilterType != .none
    }

    var timelineDefaultReadFilterType: ReadFilterType {
        self.timelineFeed?.defaultReadFilterType ?? .none
    }

    var rootNode: Node {
        self.treeController.rootNode
    }

    // At some point we should refactor the current Feed IndexPath out and only use the timeline feed
    private(set) var currentFeedIndexPath: IndexPath?

    var timelineIconImage: IconImage? {
        guard let timelineFeed else {
            return nil
        }
        return IconImageCache.shared.imageForFeed(timelineFeed)
    }

    private var exceptionArticleFetcher: ArticleFetcher?
    private(set) var timelineFeed: SidebarItem? {
        didSet {
            self.mainTimelineViewController?.updateNavigationBarTitle(self.timelineFeed?.nameForDisplay ?? "")
            self.updateNavigationBarSubtitles(nil)
        }
    }

    var timelineMiddleIndexPath: IndexPath?

    private(set) var showFeedNames = ShowFeedName.none
    private(set) var showIcons = false

    var prevFeedIndexPath: IndexPath? {
        guard let indexPath = currentFeedIndexPath else {
            return nil
        }

        let prevIndexPath: IndexPath? = {
            if indexPath.row - 1 < 0 {
                for i in (0..<indexPath.section).reversed() {
                    if self.shadowTable[i].feedNodes.count > 0 {
                        return IndexPath(row: self.shadowTable[i].feedNodes.count - 1, section: i)
                    }
                }
                return nil
            } else {
                return IndexPath(row: indexPath.row - 1, section: indexPath.section)
            }
        }()

        return prevIndexPath
    }

    var nextFeedIndexPath: IndexPath? {
        guard let indexPath = currentFeedIndexPath else {
            return nil
        }

        let nextIndexPath: IndexPath? = {
            if indexPath.row + 1 >= self.shadowTable[indexPath.section].feedNodes.count {
                for i in indexPath.section + 1..<self.shadowTable.count {
                    if self.shadowTable[i].feedNodes.count > 0 {
                        return IndexPath(row: 0, section: i)
                    }
                }
                return nil
            } else {
                return IndexPath(row: indexPath.row + 1, section: indexPath.section)
            }
        }()

        return nextIndexPath
    }

    var isPrevArticleAvailable: Bool {
        guard let articleRow = currentArticleRow else {
            return false
        }
        return articleRow > 0
    }

    var isNextArticleAvailable: Bool {
        guard let articleRow = currentArticleRow else {
            return false
        }
        return articleRow + 1 < self.articles.count
    }

    var prevArticle: Article? {
        guard self.isPrevArticleAvailable, let articleRow = currentArticleRow else {
            return nil
        }
        return self.articles[articleRow - 1]
    }

    var nextArticle: Article? {
        guard self.isNextArticleAvailable, let articleRow = currentArticleRow else {
            return nil
        }
        return self.articles[articleRow + 1]
    }

    var firstUnreadArticleIndexPath: IndexPath? {
        for (row, article) in self.articles.enumerated() {
            if !article.status.read {
                return IndexPath(row: row, section: 0)
            }
        }
        return nil
    }

    var currentArticle: Article? {
        didSet {
            if let article = currentArticle {
                AppDefaults.shared.selectedArticle = ArticleSpecifier(article: article)
            } else {
                AppDefaults.shared.selectedArticle = nil
            }
        }
    }

    private(set) var articles = ArticleArray() {
        didSet {
            self.timelineMiddleIndexPath = nil
            self.articleDictionaryNeedsUpdate = true
        }
    }

    private var articleDictionaryNeedsUpdate = true
    private var _idToArticleDictionary = [String: Article]()
    private var idToArticleDictionary: [String: Article] {
        if self.articleDictionaryNeedsUpdate {
            rebuildArticleDictionaries()
        }
        return self._idToArticleDictionary
    }

    private var currentArticleRow: Int? {
        guard let article = currentArticle else { return nil }
        return self.articles.firstIndex(of: article)
    }

    var isTimelineUnreadAvailable: Bool {
        self.timelineUnreadCount > 0
    }

    var isAnyUnreadAvailable: Bool {
        appDelegate.unreadCount > 0
    }

    var timelineUnreadCount: Int = 0 {
        didSet {
            self.updateNavigationBarSubtitles(nil)
        }
    }

    init(rootSplitViewController: RootSplitViewController) {
        self.rootSplitViewController = rootSplitViewController
        self.rootSplitViewController.minimumPrimaryColumnWidth = 300
        self.rootSplitViewController.maximumPrimaryColumnWidth = 500
        self.rootSplitViewController.minimumSupplementaryColumnWidth = 300
        self.rootSplitViewController.maximumSupplementaryColumnWidth = 500
        self.rootSplitViewController.preferredSupplementaryColumnWidthFraction = 0.4
        self.rootSplitViewController.preferredSplitBehavior = .tile

        self.treeController = TreeController(delegate: self.treeControllerDelegate)

        super.init()

        let feedNavController = rootSplitViewController.viewController(for: .primary) as? UINavigationController
        self.mainFeedCollectionViewController = feedNavController?.viewControllers
            .first as? MainFeedCollectionViewController
        self.mainFeedCollectionViewController?.coordinator = self
        feedNavController?.delegate = self
        self.updateNavigationBarSubtitles(nil)

        let timelineNavController = rootSplitViewController
            .viewController(for: .supplementary) as? UINavigationController
        self.mainTimelineViewController = timelineNavController?.viewControllers.first as? MainTimelineViewController
        self.mainTimelineViewController?.coordinator = self
        timelineNavController?.delegate = self

        let articleNavController = rootSplitViewController.viewController(for: .secondary) as? UINavigationController
        self.articleViewController = articleNavController?.viewControllers.first as? ArticleViewController
        self.articleViewController?.coordinator = self
        articleNavController?.delegate = self

        for sectionNode in self.treeController.rootNode.childNodes {
            markExpanded(sectionNode)
            self.shadowTable.append((sectionID: "", feedNodes: [FeedNode]()))
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidInitialize(_:)),
            name: .UnreadCountDidInitialize,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.statusesDidChange(_:)),
            name: .StatusesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.containerChildrenDidChange(_:)),
            name: .ChildrenDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.batchUpdateDidPerform(_:)),
            name: .BatchUpdateDidPerform,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.displayNameDidChange(_:)),
            name: .DisplayNameDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.userDidAddFeed(_:)),
            name: .UserDidAddFeed,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.dataStoreDidDownloadArticles(_:)),
            name: .DataStoreDidDownloadArticles,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.willEnterForeground(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateNavigationBarSubtitles(_:)),
            name: .combinedRefreshProgressDidChange,
            object: nil
        )

        NotificationCenter.default
            .addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.userDefaultsDidChange()
                }
            }
    }

    func restoreWindowState(activity: NSUserActivity?) {
        let stateInfo = StateRestorationInfo(legacyState: activity)
        self.restoreWindowState(stateInfo)
    }

    private func restoreWindowState(_ stateInfo: StateRestorationInfo) {
        if AppDefaults.shared.isFirstRun {
            // Expand top-level items on first run.
            for sectionNode in self.treeController.rootNode.childNodes {
                markExpanded(sectionNode)
            }
            saveExpandedContainersToUserDefaults()
        } else {
            self.expandedContainers = stateInfo.expandedContainers
        }

        self.sidebarItemsHidingReadArticles.formUnion(stateInfo.sidebarItemsHidingReadArticles)

        rebuildBackingStores(initialLoad: true)

        // You can't assign the Feeds Read Filter until we've built the backing stores at least once or there is nothing
        // for state restoration to work with while we are waiting for the unread counts to initialize.
        self.treeControllerDelegate.isReadFiltered = stateInfo.hideReadFeeds

        self.restoreSelectedSidebarItemAndArticle(stateInfo)
    }

    private func restoreSelectedSidebarItemAndArticle(_ stateInfo: StateRestorationInfo) {
        guard let selectedSidebarItem = stateInfo.selectedSidebarItem else {
            return
        }

        guard
            let feedNode = nodeFor(sidebarItemID: selectedSidebarItem),
            let indexPath = indexPathFor(feedNode) else
        {
            return
        }
        self.selectFeed(indexPath: indexPath, animations: []) {
            self.restoreSelectedArticle(stateInfo)
        }
    }

    private func restoreSelectedArticle(_ stateInfo: StateRestorationInfo) {
        guard let articleSpecifier = stateInfo.selectedArticle else {
            return
        }

        let article = self.articles.article(matching: articleSpecifier) ??
            DataStore.shared.fetchArticle(
                dataStoreID: articleSpecifier.accountID,
                articleID: articleSpecifier.articleID
            )

        if let article {
            self.selectArticle(
                article,
                isShowingExtractedArticle: stateInfo.isShowingExtractedArticle,
                articleWindowScrollY: stateInfo.articleWindowScrollY
            )
        }
    }

    func handle(_: NSUserActivity) {
        // Activity handling removed - no longer using Handoff/Spotlight
    }

    func handle(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        handleReadArticle(userInfo)
    }

    func resetFocus() {
        if self.currentArticle != nil {
            self.mainTimelineViewController?.focus()
        } else {
            self.mainFeedCollectionViewController?.focus()
        }
    }

    func selectFirstUnreadInAllUnread() {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
            self.selectFeed(SmartFeedsController.shared.unreadFeed) {
                self.selectFirstUnreadArticleInTimeline()
            }
        }
    }

    func showSearch() {
        self.selectFeed(indexPath: nil) {
            self.rootSplitViewController.show(.supplementary)
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.mainTimelineViewController!.showSearchAll()
            }
        }
    }

    // MARK: Notifications

    @objc
    func unreadCountDidInitialize(_ notification: Notification) {
        guard notification.object is DataStore else {
            return
        }

        if self.isReadFeedsFiltered {
            rebuildBackingStores()
        }
    }

    @objc
    func unreadCountDidChange(_: Notification) {
        // We will handle the filtering of unread feeds in unreadCountDidInitialize after they have all be calculated
        guard DataStore.shared.areUnreadCountsInitialized else {
            return
        }

        queueRebuildBackingStores()
    }

    @objc
    func statusesDidChange(_: Notification) {
        updateUnreadCount()
    }

    @objc
    func containerChildrenDidChange(_: Notification) {
        if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
            fetchAndMergeArticlesAsync(animated: true) {
                self.mainTimelineViewController?.reinitializeArticles(resetScroll: false)
                self.rebuildBackingStores()
            }
        } else {
            rebuildBackingStores()
        }
    }

    @objc
    func batchUpdateDidPerform(_: Notification) {
        rebuildBackingStores()
    }

    @objc
    func displayNameDidChange(_ note: Notification) {
        rebuildBackingStores()

        // Reload the cell for the object whose display name changed
        if let object = note.object, let indexPath = indexPathFor(object as AnyObject) {
            self.mainFeedCollectionViewController.collectionView.reloadItems(at: [indexPath])
        }
    }

    @objc
    func userDidAddFeed(_ notification: Notification) {
        guard let feed = notification.userInfo?[UserInfoKey.feed] as? Feed else {
            return
        }
        self.discloseFeed(feed, animations: [.scroll, .navigation])
    }

    func userDefaultsDidChange() {
        self.sortDirection = AppDefaults.shared.timelineSortDirection
        self.groupByFeed = AppDefaults.shared.timelineGroupByFeed
    }

    @objc
    func dataStoreDidDownloadArticles(_ note: Notification) {
        guard let feeds = note.userInfo?[DataStore.UserInfoKey.feeds] as? Set<Feed> else {
            return
        }

        let shouldFetchAndMergeArticles = timelineFetcherContainsAnyFeed(feeds) ||
            timelineFetcherContainsAnyPseudoFeed()
        if shouldFetchAndMergeArticles {
            queueFetchAndMergeArticles()
        }
    }

    @objc
    func willEnterForeground(_: Notification) {
        // Don't interfere with any fetch requests that we may have initiated before the app was returned to the
        // foreground.
        // For example if you select Next Unread from the Home Screen Quick actions, you can start a request before we
        // are
        // in the foreground.
        if !self.fetchRequestQueue.isAnyCurrentRequest {
            queueFetchAndMergeArticles()
        }
    }

    /// Updates navigation bar subtitles in response to feed selection, unread count changes,
    /// `combinedRefreshProgressDidChange` notifications, and a timed refresh every
    /// 60s.
    ///
    /// Subtitles are handled differently on iPhone and iPad.
    ///
    /// `MainFeedViewController`
    /// - When refreshing: Feeds will display "Updating..." on both iPhone and iPad.
    /// - When refreshed: Feeds will display "Updated <#relative_time#>" on both iPhone and iPad.
    ///
    /// `MainTimelineViewController`
    /// - Where the unread count for the timeline is > 0, this is displayed on both iPhone and iPad.
    /// - If the timeline count is 0, the iPhone follows the same logic as `MainFeedViewController`
    /// - Specific to iPad, if the unread count is 0, the iPad will not display a subtitle. The refresh text
    /// will generally be visible in the sidebar and there's no need to display it twice.
    ///
    /// - Parameter note: Optional `Notification`
    @objc
    func updateNavigationBarSubtitles(_: Notification?) {
        let progress = DataStore.shared.combinedRefreshProgress

        if progress.isComplete {
            if let lastArticleFetchEndTime = DataStore.shared.lastArticleFetchEndTime {
                if Date.now > lastArticleFetchEndTime.addingTimeInterval(60) {
                    let relativeDateTimeFormatter = RelativeDateTimeFormatter()
                    relativeDateTimeFormatter.dateTimeStyle = .named
                    let refreshed = relativeDateTimeFormatter.localizedString(
                        for: lastArticleFetchEndTime,
                        relativeTo: Date()
                    )
                    let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
                    let refreshText = NSString.localizedStringWithFormat(
                        localizedRefreshText as NSString,
                        refreshed
                    ) as String

                    // Update Feeds with Updated text
                    self.mainFeedCollectionViewController?.navigationItem.subtitle = refreshText

                    // If unread count > 0, add unread string to timeline
                    if let _ = timelineFeed, timelineUnreadCount > 0 {
                        let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                        let unreadCount = NSString.localizedStringWithFormat(
                            localizedUnreadCount as NSString,
                            self.timelineUnreadCount
                        ) as String
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(unreadCount)
                    } else {
                        // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshText)
                        } else {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                        }
                    }
                } else {
                    // Use 'Updated Just Now' while <60s have passed since refresh.
                    self.mainFeedCollectionViewController?.navigationItem.subtitle = NSLocalizedString(
                        "Updated Just Now",
                        comment: "Updated Just Now"
                    )

                    // If unread count > 0, add unread string to timeline
                    if let _ = timelineFeed, timelineUnreadCount > 0 {
                        let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                        let refreshTextWithUnreadCount = NSString.localizedStringWithFormat(
                            localizedUnreadCount as NSString,
                            self.timelineUnreadCount
                        ) as String
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshTextWithUnreadCount)
                    } else {
                        // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle(NSLocalizedString(
                                "Updated Just Now",
                                comment: "Updated Just Now"
                            ))
                        } else {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                        }
                    }
                }
            } else {
                self.mainFeedCollectionViewController?.navigationItem.subtitle = ""
                // If unread count > 0, add unread string to timeline
                if let _ = timelineFeed, timelineUnreadCount > 0 {
                    let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                    let refreshTextWithUnreadCount = NSString.localizedStringWithFormat(
                        localizedUnreadCount as NSString,
                        self.timelineUnreadCount
                    ) as String
                    self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshTextWithUnreadCount)
                } else {
                    // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(NSLocalizedString(
                            "Updated Just Now",
                            comment: "Updated Just Now"
                        ))
                    } else {
                        self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                    }
                }
            }
        } else {
            // Updating in progress, apply to both iPhone and iPad Feeds.
            self.mainFeedCollectionViewController?.navigationItem.subtitle = NSLocalizedString(
                "Updating...",
                comment: "Updating..."
            )
        }

        self.scheduleNavigationBarSubtitleUpdate()
    }

    func scheduleNavigationBarSubtitleUpdate() {
        if self.isNavigationBarSubtitleRefreshScheduled {
            return
        }
        self.isNavigationBarSubtitleRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.isNavigationBarSubtitleRefreshScheduled = false
            self?.updateNavigationBarSubtitles(nil)
        }
    }

    // MARK: API

    func suspend() {
        self.fetchAndMergeArticlesQueue.performCallsImmediately()
        self.rebuildBackingStoresQueue.performCallsImmediately()
        self.fetchRequestQueue.cancelAllRequests()
    }

    func cleanUp(conditional: Bool) {
        if self.isReadFeedsFiltered {
            rebuildBackingStores()
        }
        if self.isReadArticlesFiltered, AppDefaults.shared.refreshClearsReadArticles || !conditional {
            self.refreshTimeline(resetScroll: false)
        }
    }

    func toggleReadFeedsFilter() {
        if self.isReadFeedsFiltered {
            self.treeControllerDelegate.isReadFiltered = false
            AppDefaults.shared.hideReadFeeds = false
        } else {
            self.treeControllerDelegate.isReadFiltered = true
            AppDefaults.shared.hideReadFeeds = true
        }
        rebuildBackingStores()
        self.mainFeedCollectionViewController?.updateUI()
    }

    func toggleReadArticlesFilter() {
        guard let sidebarItemID = timelineFeed?.sidebarItemID else {
            return
        }

        if self.isReadArticlesFiltered {
            self.sidebarItemsHidingReadArticles.remove(sidebarItemID)
        } else {
            self.sidebarItemsHidingReadArticles.insert(sidebarItemID)
        }

        self.refreshTimeline(resetScroll: false)
    }

    func nodeFor(sidebarItemID: SidebarItemIdentifier) -> Node? {
        self.treeController.rootNode.descendantNode(where: { node in
            if let sidebarItem = node.representedObject as? SidebarItem {
                sidebarItem.sidebarItemID == sidebarItemID
            } else {
                false
            }
        })
    }

    func numberOfSections() -> Int {
        self.shadowTable.count
    }

    func numberOfRows(in section: Int) -> Int {
        self.shadowTable[section].feedNodes.count
    }

    func nodeFor(_ indexPath: IndexPath) -> Node? {
        guard
            indexPath.section > -1,
            indexPath.row > -1,
            indexPath.section < self.shadowTable.count,
            indexPath.row < self.shadowTable[indexPath.section].feedNodes.count else
        {
            return nil
        }
        return self.shadowTable[indexPath.section].feedNodes[indexPath.row].node
    }

    func indexPathFor(_ node: Node) -> IndexPath? {
        for i in 0..<self.shadowTable.count {
            if let row = shadowTable[i].feedNodes.firstIndex(of: FeedNode(node)) {
                return IndexPath(row: row, section: i)
            }
        }
        return nil
    }

    func articleFor(_ articleID: String) -> Article? {
        // Check if it's the currently displayed article
        if let currentArticle, currentArticle.articleID == articleID {
            return currentArticle
        }
        return self.idToArticleDictionary[articleID]
    }

    func cappedIndexPath(_ indexPath: IndexPath) -> IndexPath {
        guard
            indexPath.section < self.shadowTable.count,
            indexPath.row < self.shadowTable[indexPath.section].feedNodes.count else
        {
            return IndexPath(
                row: self.shadowTable[self.shadowTable.count - 1].feedNodes.count - 1,
                section: self.shadowTable.count - 1
            )
        }
        return indexPath
    }

    func unreadCountFor(_ node: Node) -> Int {
        // The coordinator supplies the unread count for the currently selected feed
        if node.representedObject === self.timelineFeed as AnyObject {
            return self.timelineUnreadCount
        }
        if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
            return unreadCountProvider.unreadCount
        }
        assertionFailure(
            "This method should only be called for nodes that have an UnreadCountProvider as the represented object."
        )
        return 0
    }

    func refreshTimeline(resetScroll: Bool) {
        if let article = self.currentArticle, let dataStore = article.dataStore {
            self.exceptionArticleFetcher = SingleArticleFetcher(dataStore: dataStore, articleID: article.articleID)
        }
        fetchAndReplaceArticlesAsync(animated: true) {
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: resetScroll)
        }
    }

    func isExpanded(_ containerID: ContainerIdentifier) -> Bool {
        self.expandedContainers.contains(containerID)
    }

    func isExpanded(_ containerIdentifiable: ContainerIdentifiable) -> Bool {
        if let containerID = containerIdentifiable.containerID {
            return self.isExpanded(containerID)
        }
        return false
    }

    func isExpanded(_ node: Node) -> Bool {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            return self.isExpanded(containerIdentifiable)
        }
        return false
    }

    func expand(_ containerID: ContainerIdentifier) {
        markExpanded(containerID)
        rebuildBackingStores()
        saveExpandedContainersToUserDefaults()
    }

    /// This is a special function that expects the caller to change the disclosure arrow state outside this function.
    /// Failure to do so will get the Sidebar into an invalid state.
    func expand(_ node: Node) {
        guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
        self.lastExpandedContainers.insert(containerID)
        self.expand(containerID)
    }

    func expandAllSectionsAndFolders() {
        for sectionNode in self.treeController.rootNode.childNodes {
            markExpanded(sectionNode)
            for topLevelNode in sectionNode.childNodes {
                if topLevelNode.representedObject is Folder {
                    markExpanded(topLevelNode)
                }
            }
        }
        rebuildBackingStores()
        saveExpandedContainersToUserDefaults()
    }

    func collapse(_ containerID: ContainerIdentifier) {
        unmarkExpanded(containerID)
        rebuildBackingStores()
        clearTimelineIfNoLongerAvailable()
        saveExpandedContainersToUserDefaults()
    }

    /// This is a special function that expects the caller to change the disclosure arrow state outside this function.
    /// Failure to do so will get the Sidebar into an invalid state.
    func collapse(_ node: Node) {
        guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
        self.lastExpandedContainers.remove(containerID)
        self.collapse(containerID)
    }

    func collapseAllFolders() {
        for sectionNode in self.treeController.rootNode.childNodes {
            for topLevelNode in sectionNode.childNodes {
                if topLevelNode.representedObject is Folder {
                    unmarkExpanded(topLevelNode)
                }
            }
        }
        rebuildBackingStores()
        clearTimelineIfNoLongerAvailable()
    }

    func mainFeedIndexPathForCurrentTimeline() -> IndexPath? {
        guard let node = treeController.rootNode.descendantNodeRepresentingObject(timelineFeed as AnyObject) else {
            return nil
        }
        return self.indexPathFor(node)
    }

    func selectFeed(
        _ sidebarItem: SidebarItem?,
        animations: Animations = [],
        deselectArticle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let indexPath: IndexPath? = if let sidebarItem, let indexPath = indexPathFor(sidebarItem as AnyObject) {
            indexPath
        } else {
            nil
        }
        self.selectFeed(
            indexPath: indexPath,
            animations: animations,
            deselectArticle: deselectArticle,
            completion: completion
        )
        self.updateNavigationBarSubtitles(nil)
    }

    func selectFeed(
        indexPath: IndexPath?,
        animations: Animations = [],
        deselectArticle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard indexPath != self.currentFeedIndexPath else {
            completion?()
            return
        }

        self.currentFeedIndexPath = indexPath
        self.mainFeedCollectionViewController.updateFeedSelection(animations: animations)

        if deselectArticle {
            self.selectArticle(nil)
        }

        if let ip = indexPath, let node = nodeFor(ip), let sidebarItem = node.representedObject as? SidebarItem {
            self.rootSplitViewController.show(.supplementary)
            setTimelineFeed(sidebarItem, animated: false) {
                if self.isReadFeedsFiltered {
                    self.rebuildBackingStores()
                }
                AppDefaults.shared.selectedSidebarItem = sidebarItem.sidebarItemID
                completion?()
            }

        } else {
            setTimelineFeed(nil, animated: false) {
                if self.isReadFeedsFiltered {
                    self.rebuildBackingStores()
                }
                self.rootSplitViewController.show(.primary)
                AppDefaults.shared.selectedSidebarItem = nil
                completion?()
            }
        }
        self.updateNavigationBarSubtitles(nil)
    }

    func selectPrevFeed() {
        if let indexPath = prevFeedIndexPath {
            self.selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
        }
    }

    func selectNextFeed() {
        if let indexPath = nextFeedIndexPath {
            self.selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
        }
    }

    func selectTodayFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.todayFeed) {
            self.selectFeed(
                SmartFeedsController.shared.todayFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func selectAllUnreadFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
            self.selectFeed(
                SmartFeedsController.shared.unreadFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func selectStarredFeed(completion: (() -> Void)? = nil) {
        markExpanded(SmartFeedsController.shared)
        self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.starredFeed) {
            self.selectFeed(
                SmartFeedsController.shared.starredFeed,
                animations: [.navigation, .scroll],
                completion: completion
            )
        }
    }

    func selectArticle(
        _ article: Article?,
        animations: Animations = [],
        isShowingExtractedArticle _: Bool? = nil,
        articleWindowScrollY: Int? = nil
    ) {
        guard article != self.currentArticle else { return }

        self.currentArticle = article

        if article == nil {
            self.articleViewController?.article = nil
            self.rootSplitViewController.show(.supplementary)
            self.mainTimelineViewController?.updateArticleSelection(animations: animations)
            return
        }

        self.rootSplitViewController.show(.secondary)

        // Mark article as read before navigating to it, so the read status does not flash unread/read on display
        markArticles(Set([article!]), statusKey: .read, flag: true)

        self.mainTimelineViewController?.updateArticleSelection(animations: animations)
        self.articleViewController?.article = article
        if let articleWindowScrollY {
            self.articleViewController?.restoreScrollPosition = articleWindowScrollY
        }
    }

    func beginSearching() {
        self.isSearching = true
        self.preSearchTimelineFeed = self.timelineFeed
        self.savedSearchArticles = self.articles
        self.savedSearchArticleIds = Set(self.articles.map(\.articleID))
        setTimelineFeed(nil, animated: true)
        self.selectArticle(nil)
    }

    func endSearching() {
        if let oldTimelineFeed = preSearchTimelineFeed {
            emptyTheTimeline()
            self.timelineFeed = oldTimelineFeed
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: true)
            replaceArticles(with: self.savedSearchArticles!, animated: true)
        } else {
            setTimelineFeed(nil, animated: true)
        }

        self.lastSearchString = ""
        self.lastSearchScope = nil
        self.preSearchTimelineFeed = nil
        self.savedSearchArticleIds = nil
        self.savedSearchArticles = nil
        self.isSearching = false
        self.selectArticle(nil)
        self.mainTimelineViewController?.focus()
    }

    func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
        guard self.isSearching else { return }

        if searchString.count < 3 {
            setTimelineFeed(nil, animated: true)
            return
        }

        if searchString != self.lastSearchString || searchScope != self.lastSearchScope {
            switch searchScope {
            case .global:
                let searchPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
                setTimelineFeed(
                    SmartFeed(
                        identifier: "SearchFeedDelegate",
                        nameForDisplay: searchPrefix + searchString,
                        fetchType: .search(searchString),
                        smallIcon: Assets.Images.searchFeed
                    ),
                    animated: true
                )
            case .timeline:
                let searchPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
                setTimelineFeed(
                    SmartFeed(
                        identifier: "SearchTimelineFeedDelegate",
                        nameForDisplay: searchPrefix + searchString,
                        fetchType: .searchWithArticleIDs(searchString, self.savedSearchArticleIds!),
                        smallIcon: Assets.Images.searchFeed
                    ),
                    animated: true
                )
            }

            self.lastSearchString = searchString
            self.lastSearchScope = searchScope
        }
    }

    func findPrevArticle(_ article: Article) -> Article? {
        guard let index = articles.firstIndex(of: article), index > 0 else {
            return nil
        }
        return self.articles[index - 1]
    }

    func findNextArticle(_ article: Article) -> Article? {
        guard let index = articles.firstIndex(of: article), index + 1 != articles.count else {
            return nil
        }
        return self.articles[index + 1]
    }

    func selectPrevArticle() {
        if let article = prevArticle {
            self.selectArticle(article, animations: [.navigation, .scroll])
        }
    }

    func selectNextArticle() {
        if let article = nextArticle {
            self.selectArticle(article, animations: [.navigation, .scroll])
        }
    }

    func selectFirstUnread() {
        selectFirstUnreadArticleInTimeline()
    }

    func selectPrevUnread() {
        // This should never happen, but I don't want to risk throwing us
        // into an infinite loop searching for an unread that isn't there.
        if appDelegate.unreadCount < 1 {
            return
        }

        self.isNavigationDisabled = true
        defer {
            isNavigationDisabled = false
        }

        if selectPrevUnreadArticleInTimeline() {
            return
        }

        selectPrevUnreadFeedFetcher()
        selectPrevUnreadArticleInTimeline()
    }

    func selectNextUnread() {
        // This should never happen, but I don't want to risk throwing us
        // into an infinite loop searching for an unread that isn't there.
        if appDelegate.unreadCount < 1 {
            return
        }

        self.isNavigationDisabled = true
        defer {
            isNavigationDisabled = false
        }

        if selectNextUnreadArticleInTimeline() {
            return
        }

        if self.isSearching {
            self.mainTimelineViewController?.hideSearch()
        }

        selectNextUnreadFeed {
            self.selectNextUnreadArticleInTimeline()
        }
    }

    func scrollOrGoToNextUnread() {
        if self.articleViewController?.canScrollDown() ?? false {
            self.articleViewController?.scrollPageDown()
        } else {
            self.selectNextUnread()
        }
    }

    func scrollUp() {
        if self.articleViewController?.canScrollUp() ?? false {
            self.articleViewController?.scrollPageUp()
        }
    }

    func markAllAsRead(_ articles: [Article], completion: (() -> Void)? = nil) {
        markArticlesWithUndo(articles, statusKey: .read, flag: true, completion: completion)
    }

    func markAllAsReadInTimeline(completion: (() -> Void)? = nil) {
        self.markAllAsRead(self.articles, completion: completion)
    }

    func canMarkAboveAsRead(for article: Article) -> Bool {
        let articlesAboveArray = self.articles.articlesAbove(article: article)
        return articlesAboveArray.canMarkAllAsRead()
    }

    func markAboveAsRead() {
        guard let currentArticle else {
            return
        }

        self.markAboveAsRead(currentArticle)
    }

    func markAboveAsRead(_ article: Article) {
        let articlesAboveArray = self.articles.articlesAbove(article: article)
        self.markAllAsRead(articlesAboveArray)
    }

    func canMarkBelowAsRead(for article: Article) -> Bool {
        let articleBelowArray = self.articles.articlesBelow(article: article)
        return articleBelowArray.canMarkAllAsRead()
    }

    func markBelowAsRead() {
        guard let currentArticle else {
            return
        }

        self.markBelowAsRead(currentArticle)
    }

    func markBelowAsRead(_ article: Article) {
        let articleBelowArray = self.articles.articlesBelow(article: article)
        self.markAllAsRead(articleBelowArray)
    }

    func markAsReadForCurrentArticle() {
        if let article = currentArticle {
            markArticlesWithUndo([article], statusKey: .read, flag: true)
        }
    }

    func markAsUnreadForCurrentArticle() {
        if let article = currentArticle {
            markArticlesWithUndo([article], statusKey: .read, flag: false)
        }
    }

    func toggleReadForCurrentArticle() {
        if let article = currentArticle {
            self.toggleRead(article)
        }
    }

    func toggleRead(_ article: Article) {
        guard !article.status.read || article.isAvailableToMarkUnread else { return }
        markArticlesWithUndo([article], statusKey: .read, flag: !article.status.read)
    }

    func toggleStarredForCurrentArticle() {
        if let article = currentArticle {
            self.toggleStar(article)
        }
    }

    func toggleStar(_ article: Article) {
        markArticlesWithUndo([article], statusKey: .starred, flag: !article.status.starred)
    }

    func timelineFeedIsEqualTo(_ feed: Feed) -> Bool {
        guard let timelineFeed = timelineFeed as? Feed else {
            return false
        }

        return timelineFeed == feed
    }

    func discloseFeed(
        _ feed: Feed,
        initialLoad: Bool = false,
        animations: Animations = [],
        completion: (() -> Void)? = nil
    ) {
        if self.isSearching {
            self.mainTimelineViewController?.hideSearch()
        }

        guard let dataStore = feed.dataStore else {
            completion?()
            return
        }

        let parentFolder = dataStore.sortedFolders?.first(where: { $0.objectIsChild(feed) })

        markExpanded(dataStore)
        if let parentFolder {
            markExpanded(parentFolder)
        }

        if let feedSidebarItemID = feed.sidebarItemID {
            self.treeControllerDelegate.addFilterException(feedSidebarItemID)
        }
        if let parentFolderSidebarItemID = parentFolder?.sidebarItemID {
            self.treeControllerDelegate.addFilterException(parentFolderSidebarItemID)
        }

        rebuildBackingStores(initialLoad: initialLoad, completion: {
            self.treeControllerDelegate.resetFilterExceptions()
            self.selectFeed(nil) {
                if self.rootSplitViewController.traitCollection.horizontalSizeClass == .compact {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.selectFeed(feed, animations: animations, completion: completion)
                    }
                } else {
                    self.selectFeed(feed, animations: animations, completion: completion)
                }
            }
        })
    }

    func showStatusBar() {
        self.prefersStatusBarHidden = false
        UIView.animate(withDuration: 0.15) {
            self.rootSplitViewController.setNeedsStatusBarAppearanceUpdate()
        }
    }

    func hideStatusBar() {
        self.prefersStatusBarHidden = true
        UIView.animate(withDuration: 0.15) {
            self.rootSplitViewController.setNeedsStatusBarAppearanceUpdate()
        }
    }

    func showSettings() {
        let settingsViewController = SettingsViewController()

        let settingsNavController = UINavigationController(rootViewController: settingsViewController)
        settingsNavController.modalPresentationStyle = .formSheet
        self.rootSplitViewController.present(settingsNavController, animated: true)
    }

    func showFeedInspector() {
        guard let feed = timelineFeed as? Feed ?? currentArticle?.feed else {
            return
        }
        // Try to find the container from the current feed selection
        var container: Container?
        if
            let indexPath = currentFeedIndexPath,
            let node = nodeFor(indexPath),
            let parentContainer = node.parent?.representedObject as? Container
        {
            container = parentContainer
        }
        self.showFeedInspector(for: feed, in: container)
    }

    func showFeedInspector(for feed: Feed, in container: Container? = nil) {
        let feedInspectorController = FeedInspectorViewController()
        feedInspectorController.feed = feed
        feedInspectorController.container = container ?? feed.dataStore

        let feedInspectorNavController = UINavigationController(rootViewController: feedInspectorController)
        feedInspectorNavController.modalPresentationStyle = .formSheet
        feedInspectorNavController.preferredContentSize = FeedInspectorViewController
            .preferredContentSizeForFormSheetDisplay
        self.rootSplitViewController.present(feedInspectorNavController, animated: true)
    }

    func showAddFeed(initialFeed: String? = nil, initialFeedName: String? = nil) {
        // Since Add Feed can be opened from anywhere with a keyboard shortcut, we have to deselect any currently
        // selected feeds
        self.selectFeed(nil)

        let addViewController = AddFeedViewController()
        addViewController.initialFeed = initialFeed
        addViewController.initialFeedName = initialFeedName

        let addNavViewController = UINavigationController(rootViewController: addViewController)
        addNavViewController.modalPresentationStyle = .formSheet
        addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay
        self.mainFeedCollectionViewController.present(addNavViewController, animated: true)
    }

    func showAddFolder() {
        let addViewController = AddFolderViewController()
        let addNavViewController = UINavigationController(rootViewController: addViewController)
        addNavViewController.modalPresentationStyle = .formSheet
        addNavViewController.preferredContentSize = AddFolderViewController.preferredContentSizeForFormSheetDisplay
        self.mainFeedCollectionViewController.present(addNavViewController, animated: true)
    }

    func showFullScreenImage(
        image: UIImage,
        imageTitle: String?,
        transitioningDelegate: UIViewControllerTransitioningDelegate
    ) {
        let imageVC = ImageViewController()
        imageVC.image = image
        imageVC.imageTitle = imageTitle
        imageVC.modalPresentationStyle = .currentContext
        imageVC.transitioningDelegate = transitioningDelegate
        self.rootSplitViewController.present(imageVC, animated: true)
    }

    func homePageURLForFeed(_ indexPath: IndexPath) -> URL? {
        guard
            let node = nodeFor(indexPath),
            let feed = node.representedObject as? Feed,
            let homePageURL = feed.homePageURL,
            let url = URL(string: homePageURL) else
        {
            return nil
        }
        return url
    }

    func showBrowserForFeed(_ indexPath: IndexPath) {
        if let url = homePageURLForFeed(indexPath) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func showBrowserForCurrentFeed() {
        if let ip = currentFeedIndexPath, let url = homePageURLForFeed(ip) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func showBrowserForArticle(_ article: Article) {
        guard let url = article.preferredURL else { return }
        UIApplication.shared.open(url, options: [:])
    }

    func showBrowserForCurrentArticle() {
        guard let url = currentArticle?.preferredURL else { return }
        UIApplication.shared.open(url, options: [:])
    }

    func showInAppBrowser() {
        if self.currentArticle != nil {
            self.articleViewController?.openInAppBrowser()
        } else {
            self.mainFeedCollectionViewController.openInAppBrowser()
        }
    }

    func navigateToFeeds() {
        self.mainFeedCollectionViewController?.focus()
        self.selectArticle(nil)
    }

    func navigateToTimeline() {
        if self.currentArticle == nil, self.articles.count > 0 {
            self.selectArticle(self.articles[0])
        }
        self.mainTimelineViewController?.focus()
    }

    func navigateToDetail() {
        self.articleViewController?.focus()
    }

    func toggleSidebar() {
        self.rootSplitViewController.preferredDisplayMode = self.rootSplitViewController
            .displayMode == .oneBesideSecondary ? .secondaryOnly : .oneBesideSecondary
    }

    func selectArticleInCurrentFeed(
        _ articleID: String,
        isShowingExtractedArticle: Bool? = nil,
        articleWindowScrollY: Int? = nil
    ) {
        if let article = self.articles.first(where: { $0.articleID == articleID }) {
            self.selectArticle(
                article,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
        }
    }

    /// This will dismiss the foremost view controller if the user
    /// has launched from an external action (i.e., a widget tap, or
    /// selecting an article via a notification).
    ///
    /// The dismiss is only applicable if the view controller is a
    /// `SFSafariViewController` or `SettingsViewController`,
    /// otherwise, this function does nothing.
    func dismissIfLaunchingFromExternalAction() {
        guard let presentedController = mainFeedCollectionViewController.presentedViewController else { return }

        if presentedController.isKind(of: SFSafariViewController.self) {
            presentedController.dismiss(animated: true, completion: nil)
        }
        guard let settings = presentedController.children.first as? SettingsViewController else { return }
        settings.dismiss(animated: true, completion: nil)
    }
}

// MARK: UISplitViewControllerDelegate

extension SceneCoordinator: UISplitViewControllerDelegate {
    func splitViewController(
        _: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    )
        -> UISplitViewController.Column
    {
        switch proposedTopColumn {
        case .supplementary:
            if self.currentFeedIndexPath != nil {
                .supplementary
            } else {
                .primary
            }
        case .secondary:
            if self.currentArticle != nil {
                .secondary
            } else {
                if self.currentFeedIndexPath != nil {
                    .supplementary
                } else {
                    .primary
                }
            }
        default:
            .primary
        }
    }
}

// MARK: UINavigationControllerDelegate

extension SceneCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated _: Bool
    ) {
        guard UIApplication.shared.applicationState != .background else {
            return
        }

        guard self.rootSplitViewController.isCollapsed else {
            return
        }

        // If we are showing the Feeds and only the feeds start clearing stuff
        if viewController === self.mainFeedCollectionViewController, !self.isTimelineViewControllerPending {
            self.selectFeed(nil, animations: [.scroll, .select, .navigation])
            return
        }

        // If we are using a phone and navigate away from the detail, clear up the article resources (including
        // activity).
        // Don't clear it if we have pushed an ArticleViewController, but don't yet see it on the navigation stack.
        // This happens when we are going to the next unread and we need to grab another timeline to continue.  The
        // ArticleViewController will be pushed, but we will briefly show the Timeline.  Don't clear things out when
        // that happens.
        if
            viewController === self.mainTimelineViewController, self.rootSplitViewController.isCollapsed,
            !self.isArticleViewControllerPending
        {
            self.currentArticle = nil
            self.mainTimelineViewController?.updateArticleSelection(animations: [.scroll, .select, .navigation])

            // Restore any bars hidden by the article controller
            self.showStatusBar()
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.setToolbarHidden(false, animated: true)
            return
        }
    }
}

// MARK: Private

extension SceneCoordinator {
    private func markArticlesWithUndo(
        _ articles: [Article],
        statusKey: ArticleStatus.Key,
        flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard
            let undoManager,
            let markReadCommand = MarkStatusCommand(
                initialArticles: articles,
                statusKey: statusKey,
                flag: flag,
                undoManager: undoManager,
                completion: completion
            ) else
        {
            completion?()
            return
        }
        runCommand(markReadCommand)
    }

    private func updateUnreadCount() {
        var count = 0
        for article in self.articles {
            if !article.status.read {
                count += 1
            }
        }
        self.timelineUnreadCount = count
    }

    private func rebuildArticleDictionaries() {
        var idDictionary = [String: Article]()

        for article in self.articles {
            idDictionary[article.articleID] = article
        }

        self._idToArticleDictionary = idDictionary
        self.articleDictionaryNeedsUpdate = false
    }

    private func ensureFeedIsAvailableToSelect(_ sidebarItem: SidebarItem, completion: @escaping () -> Void) {
        self.addToFilterExceptionsIfNecessary(sidebarItem)
        self.addShadowTableToFilterExceptions()

        self.rebuildBackingStores(completion: {
            self.treeControllerDelegate.resetFilterExceptions()
            completion()
        })
    }

    private func addToFilterExceptionsIfNecessary(_ sidebarItem: SidebarItem?) {
        if self.isReadFeedsFiltered, let sidebarItemID = sidebarItem?.sidebarItemID {
            if sidebarItem is SmartFeed {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
            } else if let folderFeed = sidebarItem as? Folder {
                if folderFeed.dataStore?.existingFolder(withID: folderFeed.folderID) != nil {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                }
            } else if let feed = sidebarItem as? Feed {
                if feed.dataStore?.existingFeed(withFeedID: feed.feedID) != nil {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                    self.addParentFolderToFilterExceptions(feed)
                }
            }
        }
    }

    private func addParentFolderToFilterExceptions(_ sidebarItem: SidebarItem) {
        guard
            let node = treeController.rootNode.descendantNodeRepresentingObject(sidebarItem as AnyObject),
            let folder = node.parent?.representedObject as? Folder,
            let folderSidebarItemID = folder.sidebarItemID else
        {
            return
        }

        self.treeControllerDelegate.addFilterException(folderSidebarItemID)
    }

    private func addShadowTableToFilterExceptions() {
        for section in self.shadowTable {
            for feedNode in section.feedNodes {
                if let feed = feedNode.node.representedObject as? SidebarItem, let sidebarItemID = feed.sidebarItemID {
                    self.treeControllerDelegate.addFilterException(sidebarItemID)
                }
            }
        }
    }

    private func queueRebuildBackingStores() {
        self.rebuildBackingStoresQueue.add(self, #selector(self.rebuildBackingStoresWithDefaults))
    }

    @objc
    private func rebuildBackingStoresWithDefaults() {
        self.rebuildBackingStores()
    }

    private func rebuildBackingStores(
        initialLoad: Bool = false,
        updateExpandedNodes: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        if !BatchUpdate.shared.isPerforming {
            self.addToFilterExceptionsIfNecessary(self.timelineFeed)
            self.treeController.rebuild()
            self.treeControllerDelegate.resetFilterExceptions()

            updateExpandedNodes?()
            let changes = self.rebuildShadowTable()
            self.mainFeedCollectionViewController.reloadFeeds(
                initialLoad: initialLoad,
                changes: changes,
                completion: completion
            )
        }
    }

    private func rebuildShadowTable() -> ShadowTableChanges {
        var newShadowTable = [(sectionID: String, feedNodes: [FeedNode])]()

        for i in 0..<self.treeController.rootNode.numberOfChildNodes {
            var feedNodes = [FeedNode]()
            let sectionNode = self.treeController.rootNode.childAtIndex(i)!

            if self.isExpanded(sectionNode) {
                for node in sectionNode.childNodes {
                    feedNodes.append(FeedNode(node))
                    if self.isExpanded(node) {
                        for child in node.childNodes {
                            feedNodes.append(FeedNode(child))
                        }
                    }
                }
            }

            let sectionID = (sectionNode.representedObject as? DataStore)?.dataStoreID ?? ""
            newShadowTable.append((sectionID: sectionID, feedNodes: feedNodes))
        }

        // If we have a current Feed IndexPath it is no longer valid and needs reset.
        if self.currentFeedIndexPath != nil {
            self.currentFeedIndexPath = self.indexPathFor(self.timelineFeed as AnyObject)
        }

        // Compute the differences in the shadow table rows and the expanded table entries
        var changes = [ShadowTableChanges.RowChanges]()
        let expandedTableDifference = self.lastExpandedContainers.symmetricDifference(self.expandedContainers)

        for (section, newSectionRows) in newShadowTable.enumerated() {
            var moves = Set<ShadowTableChanges.Move>()
            var inserts = Set<Int>()
            var deletes = Set<Int>()

            let oldFeedNodes = self.shadowTable.first(where: { $0.sectionID == newSectionRows.sectionID })?
                .feedNodes ?? [FeedNode]()

            let diff = newSectionRows.feedNodes.difference(from: oldFeedNodes).inferringMoves()
            for change in diff {
                switch change {
                case let .insert(offset, _, associated):
                    if let associated {
                        moves.insert(ShadowTableChanges.Move(associated, offset))
                    } else {
                        inserts.insert(offset)
                    }
                case let .remove(offset, _, associated):
                    if let associated {
                        moves.insert(ShadowTableChanges.Move(offset, associated))
                    } else {
                        deletes.insert(offset)
                    }
                }
            }

            // We need to reload the difference in expanded rows to get the disclosure arrows correct when
            // programmatically changing their state
            var reloads = Set<Int>()

            for (index, newFeedNode) in newSectionRows.feedNodes.enumerated() {
                if let newFeedNodeContainerID = (newFeedNode.node.representedObject as? Container)?.containerID {
                    if expandedTableDifference.contains(newFeedNodeContainerID) {
                        reloads.insert(index)
                    }
                }
            }

            changes.append(ShadowTableChanges.RowChanges(
                section: section,
                deletes: deletes,
                inserts: inserts,
                reloads: reloads,
                moves: moves
            ))
        }

        self.lastExpandedContainers = self.expandedContainers

        // Compute the difference in the shadow table sections
        var moves = Set<ShadowTableChanges.Move>()
        var inserts = Set<Int>()
        var deletes = Set<Int>()

        let oldSections = self.shadowTable.map(\.sectionID)
        let newSections = newShadowTable.map(\.sectionID)
        let diff = newSections.difference(from: oldSections).inferringMoves()
        for change in diff {
            switch change {
            case let .insert(offset, _, associated):
                if let associated {
                    moves.insert(ShadowTableChanges.Move(associated, offset))
                } else {
                    inserts.insert(offset)
                }
            case let .remove(offset, _, associated):
                if let associated {
                    moves.insert(ShadowTableChanges.Move(offset, associated))
                } else {
                    deletes.insert(offset)
                }
            }
        }

        self.shadowTable = newShadowTable

        return ShadowTableChanges(deletes: deletes, inserts: inserts, moves: moves, rowChanges: changes)
    }

    private func shadowTableContains(_ sidebarItem: SidebarItem) -> Bool {
        for section in self.shadowTable {
            for feedNode in section.feedNodes {
                if
                    let nodeSidebarItem = feedNode.node.representedObject as? SidebarItem,
                    nodeSidebarItem.sidebarItemID == sidebarItem.sidebarItemID
                {
                    return true
                }
            }
        }
        return false
    }

    private func clearTimelineIfNoLongerAvailable() {
        if let feed = timelineFeed, !shadowTableContains(feed) {
            self.selectFeed(nil, deselectArticle: true)
        }
    }

    private func indexPathFor(_ object: AnyObject) -> IndexPath? {
        guard let node = treeController.rootNode.descendantNodeRepresentingObject(object) else {
            return nil
        }
        return self.indexPathFor(node)
    }

    private func setTimelineFeed(_ sidebarItem: SidebarItem?, animated: Bool, completion: (() -> Void)? = nil) {
        self.timelineFeed = sidebarItem

        self.fetchAndReplaceArticlesAsync(animated: animated) {
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: true)
            completion?()
        }
    }

    private func updateShowNamesAndIcons() {
        if self.timelineFeed is Feed {
            self.showFeedNames = {
                for article in self.articles {
                    if !article.byline().isEmpty {
                        return .byline
                    }
                }
                return .none
            }()
        } else {
            self.showFeedNames = .feed
        }

        if self.showFeedNames == .feed {
            self.showIcons = true
            return
        }

        if self.showFeedNames == .none {
            self.showIcons = false
            return
        }

        for article in self.articles {
            if let authors = article.authors {
                for author in authors {
                    if author.avatarURL != nil {
                        self.showIcons = true
                        return
                    }
                }
            }
        }

        self.showIcons = false
    }

    private func markExpanded(_ containerID: ContainerIdentifier) {
        self.expandedContainers.insert(containerID)
    }

    private func markExpanded(_ containerIdentifiable: ContainerIdentifiable) {
        if let containerID = containerIdentifiable.containerID {
            self.markExpanded(containerID)
        }
    }

    private func markExpanded(_ node: Node) {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            self.markExpanded(containerIdentifiable)
        }
    }

    private func unmarkExpanded(_ containerID: ContainerIdentifier) {
        self.expandedContainers.remove(containerID)
    }

    private func unmarkExpanded(_ containerIdentifiable: ContainerIdentifiable) {
        if let containerID = containerIdentifiable.containerID {
            self.unmarkExpanded(containerID)
        }
    }

    private func unmarkExpanded(_ node: Node) {
        if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
            self.unmarkExpanded(containerIdentifiable)
        }
    }

    private func saveExpandedContainersToUserDefaults() {
        AppDefaults.shared.expandedContainers = self.expandedContainers
    }

    private func saveReadFilterEnabledTableToUserDefaults() {
        AppDefaults.shared.sidebarItemsHidingReadArticles = self.sidebarItemsHidingReadArticles
    }

    // MARK: Select Prev Unread

    @discardableResult
    private func selectPrevUnreadArticleInTimeline() -> Bool {
        let startingRow: Int = if let articleRow = currentArticleRow {
            articleRow
        } else {
            self.articles.count - 1
        }

        return self.selectPrevArticleInTimeline(startingRow: startingRow)
    }

    private func selectPrevArticleInTimeline(startingRow: Int) -> Bool {
        guard startingRow >= 0 else {
            return false
        }

        for i in (0...startingRow).reversed() {
            let article = self.articles[i]
            if !article.status.read {
                self.selectArticle(article)
                return true
            }
        }

        return false
    }

    private func selectPrevUnreadFeedFetcher() {
        let indexPath: IndexPath = if self.currentFeedIndexPath == nil {
            IndexPath(row: 0, section: 0)
        } else {
            self.currentFeedIndexPath!
        }

        // Increment or wrap around the IndexPath
        let nextIndexPath = if indexPath.row - 1 < 0 {
            if indexPath.section - 1 < 0 {
                IndexPath(
                    row: self.shadowTable[self.shadowTable.count - 1].feedNodes.count - 1,
                    section: self.shadowTable.count - 1
                )
            } else {
                IndexPath(
                    row: self.shadowTable[indexPath.section - 1].feedNodes.count - 1,
                    section: indexPath.section - 1
                )
            }
        } else {
            IndexPath(row: indexPath.row - 1, section: indexPath.section)
        }

        if self.selectPrevUnreadFeedFetcher(startingWith: nextIndexPath) {
            return
        }
        let maxIndexPath = IndexPath(
            row: shadowTable[shadowTable.count - 1].feedNodes.count - 1,
            section: self.shadowTable.count - 1
        )
        self.selectPrevUnreadFeedFetcher(startingWith: maxIndexPath)
    }

    @discardableResult
    private func selectPrevUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
        for i in (0...indexPath.section).reversed() {
            let startingRow: Int = if indexPath.section == i {
                indexPath.row
            } else {
                self.shadowTable[i].feedNodes.count - 1
            }

            for j in (0...startingRow).reversed() {
                let prevIndexPath = IndexPath(row: j, section: i)
                guard
                    let node = nodeFor(prevIndexPath),
                    let unreadCountProvider = node.representedObject as? UnreadCountProvider else
                {
                    assertionFailure()
                    return true
                }

                if self.isExpanded(node) {
                    continue
                }

                if unreadCountProvider.unreadCount > 0 {
                    self.selectFeed(indexPath: prevIndexPath, animations: [.scroll, .navigation])
                    return true
                }
            }
        }

        return false
    }

    // MARK: Select Next Unread

    @discardableResult
    private func selectFirstUnreadArticleInTimeline() -> Bool {
        self.selectNextArticleInTimeline(startingRow: 0, animated: true)
    }

    @discardableResult
    private func selectNextUnreadArticleInTimeline() -> Bool {
        let startingRow: Int = if let articleRow = currentArticleRow {
            articleRow + 1
        } else {
            0
        }

        return self.selectNextArticleInTimeline(startingRow: startingRow, animated: false)
    }

    private func selectNextArticleInTimeline(startingRow: Int, animated _: Bool) -> Bool {
        guard startingRow < self.articles.count else {
            return false
        }

        for i in startingRow..<self.articles.count {
            let article = self.articles[i]
            if !article.status.read {
                self.selectArticle(article, animations: [.scroll, .navigation])
                return true
            }
        }

        return false
    }

    private func selectNextUnreadFeed(completion: @escaping () -> Void) {
        let indexPath: IndexPath = if self.currentFeedIndexPath == nil {
            IndexPath(row: -1, section: 0)
        } else {
            self.currentFeedIndexPath!
        }

        // Increment or wrap around the IndexPath
        let nextIndexPath = if indexPath.row + 1 >= self.shadowTable[indexPath.section].feedNodes.count {
            if indexPath.section + 1 >= self.shadowTable.count {
                IndexPath(row: 0, section: 0)
            } else {
                IndexPath(row: 0, section: indexPath.section + 1)
            }
        } else {
            IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }

        self.selectNextUnreadFeed(startingWith: nextIndexPath) { found in
            if !found {
                self.selectNextUnreadFeed(startingWith: IndexPath(row: 0, section: 0)) { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
    }

    private func selectNextUnreadFeed(startingWith indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        for i in indexPath.section..<self.shadowTable.count {
            let startingRow: Int = if indexPath.section == i {
                indexPath.row
            } else {
                0
            }

            for j in startingRow..<self.shadowTable[i].feedNodes.count {
                let nextIndexPath = IndexPath(row: j, section: i)
                guard
                    let node = nodeFor(nextIndexPath),
                    let unreadCountProvider = node.representedObject as? UnreadCountProvider else
                {
                    assertionFailure()
                    completion(false)
                    return
                }

                if self.isExpanded(node) {
                    continue
                }

                if unreadCountProvider.unreadCount > 0 {
                    self.selectFeed(
                        indexPath: nextIndexPath,
                        animations: [.scroll, .navigation],
                        deselectArticle: false
                    ) {
                        self.currentArticle = nil
                        completion(true)
                    }
                    return
                }
            }
        }

        completion(false)
    }

    // MARK: Fetching Articles

    private func emptyTheTimeline() {
        if !self.articles.isEmpty {
            self.replaceArticles(with: Set<Article>(), animated: false)
        }
    }

    private func sortParametersDidChange() {
        self.replaceArticles(with: Set(self.articles), animated: true)
    }

    private func replaceArticles(with unsortedArticles: Set<Article>, animated: Bool) {
        let sortedArticles = Array(unsortedArticles).sortedByDate(self.sortDirection, groupByFeed: self.groupByFeed)
        self.replaceArticles(with: sortedArticles, animated: animated)
    }

    private func replaceArticles(with sortedArticles: ArticleArray, animated: Bool) {
        if self.articles != sortedArticles {
            self.articles = sortedArticles

            // Clear current article if it's no longer in the timeline
            if
                let currentArticle,
                !sortedArticles
                    .contains(where: { $0.articleID == currentArticle.articleID && $0.accountID == currentArticle.accountID
                    })
            {
                self.selectArticle(nil)
            }

            self.updateShowNamesAndIcons()
            self.updateUnreadCount()
            self.mainTimelineViewController?.reloadArticles(animated: animated)
        }
    }

    private func queueFetchAndMergeArticles() {
        self.fetchAndMergeArticlesQueue.add(self, #selector(self.fetchAndMergeArticlesAsync))
    }

    @objc
    private func fetchAndMergeArticlesAsync() {
        self.fetchAndMergeArticlesAsync(animated: true) {
            self.mainTimelineViewController?.reinitializeArticles(resetScroll: false)
            self.mainTimelineViewController?.restoreSelectionIfNecessary(adjustScroll: false)
        }
    }

    private func fetchAndMergeArticlesAsync(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let timelineFeed else {
            return
        }

        self.fetchUnsortedArticlesAsync(for: [timelineFeed]) { [weak self] unsortedArticles in
            // Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
            guard let strongSelf = self else {
                return
            }
            let unsortedArticleIDs = unsortedArticles.articleIDs()
            var updatedArticles = unsortedArticles
            for article in strongSelf.articles {
                if !unsortedArticleIDs.contains(article.articleID) {
                    updatedArticles.insert(article)
                }
                if article.dataStore?.existingFeed(withFeedID: article.feedID) == nil {
                    updatedArticles.remove(article)
                }
            }

            strongSelf.replaceArticles(with: updatedArticles, animated: animated)
            completion?()
        }
    }

    private func cancelPendingAsyncFetches() {
        self.fetchSerialNumber += 1
        self.fetchRequestQueue.cancelAllRequests()
    }

    private func fetchAndReplaceArticlesAsync(animated: Bool, completion: @escaping () -> Void) {
        // To be called when we need to do an entire fetch, but an async delay is okay.
        // Example: we have the Today feed selected, and the calendar day just changed.
        self.cancelPendingAsyncFetches()
        guard let timelineFeed else {
            self.emptyTheTimeline()
            completion()
            return
        }

        var fetchers = [ArticleFetcher]()
        fetchers.append(timelineFeed)
        if self.exceptionArticleFetcher != nil {
            fetchers.append(self.exceptionArticleFetcher!)
            self.exceptionArticleFetcher = nil
        }

        self.fetchUnsortedArticlesAsync(for: fetchers) { [weak self] articles in
            self?.replaceArticles(with: articles, animated: animated)
            completion()
        }
    }

    private func fetchUnsortedArticlesAsync(for representedObjects: [Any], completion: @escaping ArticleSetBlock) {
        // The callback will *not* be called if the fetch is no longer relevant — that is,
        // if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
        precondition(Thread.isMainThread)
        self.cancelPendingAsyncFetches()

        let fetchers = representedObjects.compactMap { $0 as? ArticleFetcher }
        let fetchOperation = FetchRequestOperation(
            id: fetchSerialNumber,
            readFilterEnabledTable: readFilterEnabledTable,
            fetchers: fetchers
        ) { [weak self] articles, operation in
            precondition(Thread.isMainThread)
            guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
                return
            }
            completion(articles)
        }

        self.fetchRequestQueue.add(fetchOperation)
    }

    private func timelineFetcherContainsAnyPseudoFeed() -> Bool {
        if self.timelineFeed is PseudoFeed {
            return true
        }
        return false
    }

    private func timelineFetcherContainsAnyFolder() -> Bool {
        if self.timelineFeed is Folder {
            return true
        }
        return false
    }

    private func timelineFetcherContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
        // Return true if there’s a match or if a folder contains (recursively) one of feeds

        if let feed = timelineFeed as? Feed {
            for oneFeed in feeds {
                if feed.feedID == oneFeed.feedID || feed.url == oneFeed.url {
                    return true
                }
            }
        } else if let folder = timelineFeed as? Folder {
            for oneFeed in feeds {
                if folder.hasFeed(with: oneFeed.feedID) || folder.hasFeed(withURL: oneFeed.url) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: NSUserActivity

    private func windowState() -> [AnyHashable: Any] {
        let containerExpandedWindowState = self.expandedContainers.map(\.userInfo)
        var readArticlesFilterState = [[AnyHashable: AnyHashable]: Bool]()
        for key in self.readFilterEnabledTable.keys {
            readArticlesFilterState[key.userInfo] = self.readFilterEnabledTable[key]
        }
        return [
            UserInfoKey.readFeedsFilterState: self.isReadFeedsFiltered,
            UserInfoKey.containerExpandedWindowState: containerExpandedWindowState,
            UserInfoKey.readArticlesFilterState: readArticlesFilterState,
        ]
    }

    private func handleSelectFeed(_ userInfo: [AnyHashable: Any]?) {
        guard
            let userInfo,
            let sidebarItemIDUserInfo = userInfo[UserInfoKey.sidebarItemID] as? [String: String],
            let sidebarItemID = SidebarItemIdentifier(userInfo: sidebarItemIDUserInfo) else
        {
            return
        }

        self.treeControllerDelegate.addFilterException(sidebarItemID)

        switch sidebarItemID {
        case .smartFeed:
            guard let smartFeed = SmartFeedsController.shared.find(by: sidebarItemID) else { return }

            self.markExpanded(SmartFeedsController.shared)
            self.rebuildBackingStores(initialLoad: true, completion: {
                self.treeControllerDelegate.resetFilterExceptions()
                if let indexPath = self.indexPathFor(smartFeed) {
                    self.selectFeed(indexPath: indexPath) {
                        self.mainFeedCollectionViewController.focus()
                    }
                }
            })

        case .script:
            break

        case let .folder(accountID, folderName):
            guard
                let dataStoreNode = self.findDataStoreNode(dataStoreID: accountID),
                let dataStore = dataStoreNode.representedObject as? DataStore else
            {
                return
            }

            self.markExpanded(dataStore)

            self.rebuildBackingStores(initialLoad: true, completion: {
                self.treeControllerDelegate.resetFilterExceptions()

                if
                    let folderNode = self.findFolderNode(folderName: folderName, beginningAt: dataStoreNode),
                    let indexPath = self.indexPathFor(folderNode)
                {
                    self.selectFeed(indexPath: indexPath) {
                        self.mainFeedCollectionViewController.focus()
                    }
                }
            })

        case let .feed(accountID, feedID):
            guard
                let dataStoreNode = findDataStoreNode(dataStoreID: accountID),
                let dataStore = dataStoreNode.representedObject as? DataStore,
                let feed = dataStore.existingFeed(withFeedID: feedID) else
            {
                return
            }

            self.discloseFeed(feed, initialLoad: true) {
                self.mainFeedCollectionViewController.focus()
            }
        }
    }

    private func handleReadArticle(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return }

        guard
            let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
            let dataStoreID = articlePathUserInfo[ArticlePathKey.dataStoreID] as? String,
            let dataStoreName = articlePathUserInfo[ArticlePathKey.dataStoreName] as? String,
            let feedID = articlePathUserInfo[ArticlePathKey.feedID] as? String,
            let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String,
            let dataStoreNode = findDataStoreNode(dataStoreID: dataStoreID, dataStoreName: dataStoreName),
            let dataStore = dataStoreNode.representedObject as? DataStore else
        {
            return
        }

        self.exceptionArticleFetcher = SingleArticleFetcher(dataStore: dataStore, articleID: articleID)

        if self.restoreFeedSelection(userInfo, dataStoreID: dataStoreID, feedID: feedID, articleID: articleID) {
            return
        }

        guard let feed = dataStore.existingFeed(withFeedID: feedID) else {
            return
        }

        self.discloseFeed(feed) {
            self.selectArticleInCurrentFeed(articleID)
        }
    }

    private func restoreFeedSelection(
        _ userInfo: [AnyHashable: Any],
        dataStoreID _: String,
        feedID _: String,
        articleID: String
    )
        -> Bool
    {
        guard
            let sidebarItemIDUserInfo =
            (userInfo[UserInfoKey.sidebarItemID] ?? userInfo[UserInfoKey.feedIdentifier]) as? [String: String],
            let sidebarItemID = SidebarItemIdentifier(userInfo: sidebarItemIDUserInfo) else
        {
            return false
        }

        // Read values from UserDefaults (migration happens in restoreWindowState)
        let isShowingExtractedArticle = AppDefaults.shared.isShowingExtractedArticle
        let articleWindowScrollY = AppDefaults.shared.articleWindowScrollY

        switch sidebarItemID {
        case .script:
            return false

        case .smartFeed, .folder:
            let found = self.selectFeedAndArticle(
                sidebarItemID: sidebarItemID,
                articleID: articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
            if found {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
            }
            return found

        case .feed:
            let found = self.selectFeedAndArticle(
                sidebarItemID: sidebarItemID,
                articleID: articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
            if found {
                self.treeControllerDelegate.addFilterException(sidebarItemID)
                if
                    let feedNode = nodeFor(sidebarItemID: sidebarItemID),
                    let folder = feedNode.parent?.representedObject as? Folder,
                    let folderSidebarItemID = folder.sidebarItemID
                {
                    self.treeControllerDelegate.addFilterException(folderSidebarItemID)
                }
            }
            return found
        }
    }

    private func findDataStoreNode(dataStoreID: String, dataStoreName: String? = nil) -> Node? {
        if
            let node = treeController.rootNode
                .descendantNode(where: { ($0.representedObject as? DataStore)?.dataStoreID == dataStoreID })
        {
            return node
        }

        if
            let dataStoreName,
            let node = treeController.rootNode
                .descendantNode(where: { ($0.representedObject as? DataStore)?.nameForDisplay == dataStoreName })
        {
            return node
        }

        return nil
    }

    private func findFolderNode(folderName: String, beginningAt startingNode: Node) -> Node? {
        if
            let node = startingNode
                .descendantNode(where: { ($0.representedObject as? Folder)?.nameForDisplay == folderName })
        {
            return node
        }
        return nil
    }

    private func findFeedNode(feedID: String, beginningAt startingNode: Node) -> Node? {
        if let node = startingNode.descendantNode(where: { ($0.representedObject as? Feed)?.feedID == feedID }) {
            return node
        }
        return nil
    }

    private func selectFeedAndArticle(
        sidebarItemID: SidebarItemIdentifier,
        articleID: String,
        isShowingExtractedArticle: Bool,
        articleWindowScrollY: Int
    )
        -> Bool
    {
        guard
            let feedNode = nodeFor(sidebarItemID: sidebarItemID),
            let feedIndexPath = indexPathFor(feedNode) else { return false }

        self.selectFeed(indexPath: feedIndexPath) {
            self.selectArticleInCurrentFeed(
                articleID,
                isShowingExtractedArticle: isShowingExtractedArticle,
                articleWindowScrollY: articleWindowScrollY
            )
        }

        return true
    }
}
