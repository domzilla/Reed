//
//  SceneCoordinator.swift
//  Reed
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SafariServices
import UIKit
import UserNotifications

extension Notification.Name {
    static let UserDidAddFeed = Notification.Name("UserDidAddFeedNotification")
}

struct SingleArticleFetcher: ArticleFetcher {
    let dataStore: DataStore
    let articleID: String

    func fetchArticles() throws -> Set<Article> {
        try self.dataStore.fetchArticles(.articleIDs(Set([self.articleID])))
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await self.dataStore.fetchArticlesAsync(.articleIDs(Set([self.articleID])))
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.dataStore.fetchArticles(.articleIDs(Set([self.articleID])))
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        try await self.dataStore.fetchArticlesAsync(.articleIDs(Set([self.articleID])))
    }
}

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

    var rootSplitViewController: RootSplitViewController!

    var mainFeedCollectionViewController: MainFeedCollectionViewController!
    var mainTimelineViewController: MainTimelineViewController?
    var articleViewController: ArticleViewController?

    let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
    let rebuildBackingStoresQueue = CoalescingQueue(name: "Rebuild The Backing Stores", interval: 0.5)
    var fetchSerialNumber = 0
    let fetchRequestQueue = FetchRequestQueue()

    // Which Containers are expanded
    var expandedContainers = Set<ContainerIdentifier>()

    // Which Containers used to be expanded. Reset by rebuilding the Shadow Table.
    var lastExpandedContainers = Set<ContainerIdentifier>()

    // Which SidebarItems have the Read Articles Filter enabled
    var sidebarItemsHidingReadArticles = Set<SidebarItemIdentifier>()

    // Flattened tree structure for the Sidebar
    var shadowTable = [(sectionID: String, feedNodes: [FeedNode])]()

    var preSearchTimelineFeed: SidebarItem?
    var lastSearchString = ""
    var lastSearchScope: SearchScope?
    var isSearching: Bool = false
    var savedSearchArticles: ArticleArray?
    var savedSearchArticleIds: Set<String>?

    var isTimelineViewControllerPending = false
    var isArticleViewControllerPending = false

    /// `Bool` to track whether a refresh is scheduled.
    var isNavigationBarSubtitleRefreshScheduled: Bool = false

    var sortDirection = AppDefaults.shared.timelineSortDirection {
        didSet {
            if self.sortDirection != oldValue {
                self.sortParametersDidChange()
            }
        }
    }

    var groupByFeed = AppDefaults.shared.timelineGroupByFeed {
        didSet {
            if self.groupByFeed != oldValue {
                self.sortParametersDidChange()
            }
        }
    }

    var prefersStatusBarHidden = false

    let treeControllerDelegate = SidebarTreeControllerDelegate()
    let treeController: TreeController

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
    var currentFeedIndexPath: IndexPath?

    var timelineIconImage: IconImage? {
        guard let timelineFeed else {
            return nil
        }
        return IconImageCache.shared.imageForFeed(timelineFeed)
    }

    var exceptionArticleFetcher: ArticleFetcher?
    var timelineFeed: SidebarItem? {
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
            self.rebuildArticleDictionaries()
        }
        return self._idToArticleDictionary
    }

    var currentArticleRow: Int? {
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

    // MARK: - Initialization

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

    // MARK: - API

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

    // MARK: - Core Utilities

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

    func timelineFeedIsEqualTo(_ feed: Feed) -> Bool {
        guard let timelineFeed = timelineFeed as? Feed else {
            return false
        }

        return timelineFeed == feed
    }

    func updateUnreadCount() {
        var count = 0
        for article in self.articles {
            if !article.status.read {
                count += 1
            }
        }
        self.timelineUnreadCount = count
    }

    func replaceArticles(with unsortedArticles: Set<Article>, animated: Bool) {
        let sortedArticles = Array(unsortedArticles).sortedByDate(self.sortDirection, groupByFeed: self.groupByFeed)
        self.replaceArticles(with: sortedArticles, animated: animated)
    }

    func replaceArticles(with sortedArticles: ArticleArray, animated: Bool) {
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

    // MARK: - Private

    private func rebuildArticleDictionaries() {
        var idDictionary = [String: Article]()

        for article in self.articles {
            idDictionary[article.articleID] = article
        }

        self._idToArticleDictionary = idDictionary
        self.articleDictionaryNeedsUpdate = false
    }

    private func sortParametersDidChange() {
        self.replaceArticles(with: Set(self.articles), animated: true)
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
}

// MARK: - UISplitViewControllerDelegate

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

// MARK: - UINavigationControllerDelegate

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
