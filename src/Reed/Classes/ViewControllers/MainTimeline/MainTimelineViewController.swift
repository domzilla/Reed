//
//  MainTimelineViewController.swift
//  Reed
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit

final class MainTimelineViewController: UITableViewController, UndoableCommandRunner {
    private lazy var feedTapGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(showFeedInspector(_:))
    )

    private var refreshProgressView: RefreshProgressView?

    private lazy var markAllAsReadButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .plain,
            target: self,
            action: #selector(markAllAsReadAction(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
        return item
    }()

    private lazy var filterButton = UIBarButtonItem(
        image: Assets.Images.filter,
        style: .plain,
        target: self,
        action: #selector(toggleFilter(_:))
    )
    private lazy var firstUnreadButton = UIBarButtonItem(
        image: Assets.Images.nextUnread,
        style: .plain,
        target: self,
        action: #selector(firstUnread(_:))
    )

    lazy var dataSource = makeDataSource()
    private let searchController = UISearchController(searchResultsController: nil)

    weak var coordinator: SceneCoordinator?
    var undoableCommands = [UndoableCommand]()
    let scrollPositionQueue = CoalescingQueue(name: "Timeline Scroll Position", interval: 0.3, maxInterval: 1.0)

    var timelineFeed: SidebarItem? {
        assert(self.coordinator != nil)
        return self.coordinator?.timelineFeed
    }

    var showIcons: Bool {
        self.coordinator?.showIcons ?? false
    }

    private var currentArticle: Article? {
        assert(self.coordinator != nil)
        return self.coordinator?.currentArticle
    }

    var timelineMiddleIndexPath: IndexPath? {
        get {
            self.coordinator?.timelineMiddleIndexPath
        }
        set {
            self.coordinator?.timelineMiddleIndexPath = newValue
        }
    }

    private var isTimelineViewControllerPending: Bool {
        get {
            self.coordinator?.isTimelineViewControllerPending ?? false
        }
        set {
            self.coordinator?.isTimelineViewControllerPending = newValue
        }
    }

    private var timelineIconImage: IconImage? {
        assert(self.coordinator != nil)
        return self.coordinator?.timelineIconImage
    }

    private var timelineDefaultReadFilterType: ReadFilterType {
        self.timelineFeed?.defaultReadFilterType ?? .none
    }

    private var isReadArticlesFiltered: Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.isReadArticlesFiltered ?? false
    }

    private var isTimelineUnreadAvailable: Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.isTimelineUnreadAvailable ?? false
    }

    private var isRootSplitCollapsed: Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.isRootSplitCollapsed ?? false
    }

    private var articles: ArticleArray? {
        assert(self.coordinator != nil)
        return self.coordinator?.articles
    }

    private let keyboardManager = KeyboardManager(type: .timeline)
    override var keyCommands: [UIKeyCommand]? {
        // If the first responder is the WKWebView (PreloadedWebView) we don't want to supply any keyboard
        // commands that the system is looking for by going up the responder chain. They will interfere with
        // the WKWebViews built in hardware keyboard shortcuts, specifically the up and down arrow keys.
        guard let current = UIResponder.currentFirstResponder, !(current is PreloadedWebView) else { return nil }

        return self.keyboardManager.keyCommands
    }

    private lazy var titleIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),
        ])
        imageView.isHidden = true
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.font = font.fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? font
        label.numberOfLines = 1
        label.textAlignment = .center
        return label
    }()

    private lazy var navigationBarTitleView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [self.titleIconImageView, self.titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        let tap = UITapGestureRecognizer(target: self, action: #selector(showFeedInspector(_:)))
        stack.addGestureRecognizer(tap)
        stack.isUserInteractionEnabled = true
        stack.addInteraction(UIPointerInteraction(delegate: nil))
        return stack
    }()

    private var navigationBarSubtitleTitleLabel: UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(showFeedInspector(_:)))
        label.addGestureRecognizer(tap)
        return label
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        assert(self.coordinator != nil)

        super.viewDidLoad()

        // Register cells
        self.tableView.register(MainTimelineIconFeedCell.self, forCellReuseIdentifier: "MainTimelineIconFeedCell")

        // Set up toolbar items
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [self.markAllAsReadButton, flexSpace]

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
            selector: #selector(self.feedIconDidBecomeAvailable(_:)),
            name: .feedIconDidBecomeAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.avatarDidBecomeAvailable(_:)),
            name: .avatarDidBecomeAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.faviconDidBecomeAvailable(_:)),
            name: .FaviconDidBecomeAvailable,
            object: nil
        )

        // TODO: fix this temporary hack, which will probably require refactoring image handling.
        // We want to know when to possibly reconfigure our cells with a new image, and we don't
        // always know when an image is available — but watching the .htmlMetadataAvailable Notification
        // lets us know that it's time to request an image.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.faviconDidBecomeAvailable(_:)),
            name: .htmlMetadataAvailable,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.displayNameDidChange),
            name: .DisplayNameDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.willEnterForeground(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Setup the Search Controller
        self.searchController.delegate = self
        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.delegate = self
        self.searchController.searchBar.placeholder = NSLocalizedString("Search Articles", comment: "Search Articles")
        self.searchController.searchBar.scopeButtonTitles = [
            NSLocalizedString("Here", comment: "Here"),
            NSLocalizedString("All Articles", comment: "All Articles"),
        ]
        navigationItem.searchController = self.searchController

        if traitCollection.userInterfaceIdiom == .pad {
            self.searchController.searchBar.selectedScopeButtonIndex = 1
            navigationItem.searchBarPlacementAllowsExternalIntegration = true
        }
        definesPresentationContext = true

        // Configure the table
        self.tableView.dataSource = self.dataSource
        self.tableView.isPrefetchingEnabled = false

        refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action: #selector(self.refreshAccounts(_:)), for: .valueChanged)

        self.configureToolbar()
        self.resetUI(resetScroll: true)

        // Load the table and then scroll to the saved position if available
        self.applyChanges(animated: false) {
            if let restoreIndexPath = self.timelineMiddleIndexPath {
                self.tableView.scrollToRow(at: restoreIndexPath, at: .middle, animated: false)
            }
        }

        // Disable swipe back on iPad Mice
        guard let gesture = self.navigationController?.interactivePopGestureRecognizer as? UIPanGestureRecognizer else {
            return
        }
        gesture.allowedScrollTypesMask = []

        navigationItem.titleView = self.navigationBarTitleView
        navigationItem.subtitleView = self.navigationBarSubtitleTitleLabel
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isToolbarHidden = false

        // If the nav bar is hidden, fade it in to avoid it showing stuff as it is getting laid out
        if navigationController?.navigationBar.isHidden ?? false {
            navigationController?.navigationBar.alpha = 0
        }
        self.updateNavigationBarTitle(self.timelineFeed?.nameForDisplay ?? NSLocalizedString(
            "Timeline",
            comment: "Timeline"
        ))
        self.updateNavigationBarSubtitle("")
    }

    override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)
        self.isTimelineViewControllerPending = false
        if navigationController?.navigationBar.alpha == 0 {
            UIView.animate(withDuration: 0.5) {
                self.navigationController?.navigationBar.alpha = 1
            }
        }
        if traitCollection.userInterfaceIdiom == .phone {
            if let _ = coordinator?.currentArticle {
                if let indexPath = tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
                self.coordinator?.selectArticle(nil)
            }
        }
    }

    // MARK: Actions

    @objc
    func openInBrowser(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.showBrowserForCurrentArticle()
    }

    @objc
    func openInAppBrowser(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.showInAppBrowser()
    }

    @objc
    func toggleFilter(_: Any) {
        assert(self.coordinator != nil)
        self.coordinator?.toggleReadArticlesFilter()
    }

    private func markAllAsReadInTimeline() {
        assert(self.coordinator != nil)
        self.coordinator?.markAllAsReadInTimeline()
    }

    @objc
    func markAllAsReadAction(_ sender: Any) {
        let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")

        if let source = sender as? UIBarButtonItem {
            let alert = UIAlertController.markAsReadActionSheet(confirmTitle: title, source: source) { [weak self] in
                self?.markAllAsReadInTimeline()
            }
            self.present(alert, animated: true)
        }

        if let _ = sender as? UIKeyCommand {
            guard
                let indexPath = tableView.indexPathForSelectedRow,
                let contentView = tableView.cellForRow(at: indexPath)?.contentView else
            {
                return
            }

            let alert = UIAlertController
                .markAsReadActionSheet(confirmTitle: title, source: contentView) { [weak self] in
                    self?.markAllAsReadInTimeline()
                }
            self.present(alert, animated: true)
        }
    }

    @objc
    func firstUnread(_: Any) {
        assert(self.coordinator != nil)
        self.coordinator?.selectFirstUnread()
    }

    @objc
    func refreshAccounts(_: Any) {
        refreshControl?.endRefreshing()

        // This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
        // If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never
        // disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appDelegate.manualRefresh(errorHandler: self.errorPresenter())
        }
    }

    // MARK: Keyboard shortcuts

    @objc
    func selectNextUp(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.selectPrevArticle()
    }

    @objc
    func selectNextDown(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.selectNextArticle()
    }

    @objc
    func navigateToSidebar(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.navigateToFeeds()
    }

    @objc
    func navigateToDetail(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.navigateToDetail()
    }

    @objc
    func showFeedInspector(_: Any?) {
        assert(self.coordinator != nil)
        self.coordinator?.showFeedInspector()
    }

    // MARK: API

    func restoreSelectionIfNecessary(adjustScroll: Bool) {
        if let article = currentArticle, let indexPath = dataSource.indexPath(for: article) {
            if adjustScroll {
                self.tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: [])
            } else {
                self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }

    func updateNavigationBarTitle(_ text: String) {
        self.titleLabel.text = text
        self.navigationBarTitleView.isUserInteractionEnabled = ((self.coordinator?.timelineFeed as? PseudoFeed) == nil)
        self.updateNavigationBarIcon()
    }

    func updateNavigationBarIcon() {
        if let iconImage = self.coordinator?.timelineIconImage {
            self.titleIconImageView.image = iconImage.image
            if iconImage.isSymbol, let preferredColor = iconImage.preferredColor {
                self.titleIconImageView.tintColor = UIColor(cgColor: preferredColor)
            } else {
                self.titleIconImageView.tintColor = nil
            }
            self.titleIconImageView.layer.cornerRadius = iconImage.isSymbol ? 0 : 4
            self.titleIconImageView.isHidden = false
        } else {
            self.titleIconImageView.isHidden = true
        }
    }

    func updateNavigationBarSubtitle(_: String) {
        // Don't show subtitle to match storyboard behavior
        if let label = navigationItem.subtitleView as? UILabel {
            label.text = ""
            label.sizeToFit()
        }
    }

    func reinitializeArticles(resetScroll: Bool) {
        self.resetUI(resetScroll: resetScroll)
    }

    func reloadArticles(animated: Bool) {
        self.applyChanges(animated: animated)
    }

    func updateArticleSelection(animations: Animations) {
        if let article = currentArticle, let indexPath = dataSource.indexPath(for: article) {
            if self.tableView.indexPathForSelectedRow != indexPath {
                self.tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: animations)
            }
        } else {
            self.tableView.selectRow(at: nil, animated: animations.contains(.select), scrollPosition: .none)
        }

        self.updateUI()
    }

    func updateUI() {
        self.refreshProgressView?.update()
        self.updateToolbar()
    }

    func hideSearch() {
        navigationItem.searchController?.isActive = false
    }

    func showSearchAll() {
        navigationItem.searchController?.isActive = true
        navigationItem.searchController?.searchBar.selectedScopeButtonIndex = 1
        navigationItem.searchController?.searchBar.becomeFirstResponder()
    }

    func focus() {
        becomeFirstResponder()
    }

    // MARK: - Table view

    override func tableView(
        _: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    )
        -> UISwipeActionsConfiguration?
    {
        guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard !article.status.read || article.isAvailableToMarkUnread else { return nil }

        // Set up the read action
        let readTitle = article.status.read ?
            NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
            NSLocalizedString("Mark as Read", comment: "Mark as Read")

        let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] _, _, completion in
            self?.toggleRead(article)
            completion(true)
        }

        readAction.image = article.status.read ? Assets.Images.circleClosed : Assets.Images.circleOpen
        readAction.backgroundColor = Assets.Colors.primaryAccent

        return UISwipeActionsConfiguration(actions: [readAction])
    }

    override func tableView(
        _: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    )
        -> UISwipeActionsConfiguration?
    {
        guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }

        // Set up the star action
        let starTitle = article.status.starred ?
            NSLocalizedString("Unstar", comment: "Unstar") :
            NSLocalizedString("Star", comment: "Star")

        let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] _, _, completion in
            self?.toggleStar(article)
            completion(true)
        }

        starAction.image = article.status.starred ? Assets.Images.starOpen : Assets.Images.starClosed
        starAction.backgroundColor = Assets.Colors.star

        // Set up the read action
        let moreTitle = NSLocalizedString("More", comment: "More")
        let moreAction = UIContextualAction(style: .normal, title: moreTitle) { [weak self] _, view, completion in
            if let self {
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                if let popoverController = alert.popoverPresentationController {
                    popoverController.sourceView = view
                    popoverController.sourceRect = CGRect(
                        x: view.frame.size.width / 2,
                        y: view.frame.size.height / 2,
                        width: 1,
                        height: 1
                    )
                }

                if let action = self.markAboveAsReadAlertAction(article, indexPath: indexPath, completion: completion) {
                    alert.addAction(action)
                }

                if let action = self.markBelowAsReadAlertAction(article, indexPath: indexPath, completion: completion) {
                    alert.addAction(action)
                }

                if let action = self.discloseFeedAlertAction(article, completion: completion) {
                    alert.addAction(action)
                }

                if
                    let action = self.markAllInFeedAsReadAlertAction(
                        article,
                        indexPath: indexPath,
                        completion: completion
                    )
                {
                    alert.addAction(action)
                }

                if let action = self.openInBrowserAlertAction(article, completion: completion) {
                    alert.addAction(action)
                }

                if let action = self.shareAlertAction(article, indexPath: indexPath, completion: completion) {
                    alert.addAction(action)
                }

                let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
                alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                    completion(true)
                })

                self.present(alert, animated: true)
            }
        }

        moreAction.image = Assets.Images.more
        moreAction.backgroundColor = UIColor.systemGray

        return UISwipeActionsConfiguration(actions: [starAction, moreAction])
    }

    override func tableView(
        _: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point _: CGPoint
    )
        -> UIContextMenuConfiguration?
    {
        guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }

        return UIContextMenuConfiguration(
            identifier: indexPath.row as NSCopying,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                var menuElements = [UIMenuElement]()

                var markActions = [UIAction]()
                if let action = self.toggleArticleReadStatusAction(article) {
                    markActions.append(action)
                }
                markActions.append(self.toggleArticleStarStatusAction(article))
                if let action = self.markAboveAsReadAction(article, indexPath: indexPath) {
                    markActions.append(action)
                }
                if let action = self.markBelowAsReadAction(article, indexPath: indexPath) {
                    markActions.append(action)
                }
                menuElements.append(UIMenu(title: "", options: .displayInline, children: markActions))

                var secondaryActions = [UIAction]()
                if let action = self.discloseFeedAction(article) {
                    secondaryActions.append(action)
                }
                if let action = self.markAllInFeedAsReadAction(article, indexPath: indexPath) {
                    secondaryActions.append(action)
                }
                if !secondaryActions.isEmpty {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: secondaryActions))
                }

                var copyActions = [UIAction]()
                if let action = self.copyArticleURLAction(article) {
                    copyActions.append(action)
                }
                if let action = self.copyExternalURLAction(article) {
                    copyActions.append(action)
                }
                if !copyActions.isEmpty {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: copyActions))
                }

                if let action = self.openInBrowserAction(article) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [action]))
                }

                if let action = self.shareAction(article, indexPath: indexPath) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [action]))
                }

                return UIMenu(title: "", children: menuElements)
            }
        )
    }

    override func tableView(
        _ tableView: UITableView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    )
        -> UITargetedPreview?
    {
        guard
            let row = configuration.identifier as? Int,
            let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) else
        {
            return nil
        }

        let previewView = cell.contentView
        let inset: CGFloat = 12
        let visibleBounds = previewView.bounds.insetBy(dx: inset, dy: 2)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: visibleBounds,
            cornerRadius: 20
        )
        return UITargetedPreview(view: previewView, parameters: parameters)
    }

    override func tableView(
        _ tableView: UITableView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    )
        -> UITargetedPreview?
    {
        guard
            let row = configuration.identifier as? Int,
            let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) else
        {
            return nil
        }

        let previewView = cell.contentView
        let inset: CGFloat = 0
        let visibleBounds = previewView.bounds.insetBy(dx: inset, dy: 2)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: visibleBounds,
            cornerRadius: 20
        )

        return UITargetedPreview(view: previewView, parameters: parameters)
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        becomeFirstResponder()
        let article = self.dataSource.itemIdentifier(for: indexPath)
        self.coordinator?.selectArticle(article, animations: [.scroll, .select, .navigation])
    }

    override func scrollViewDidScroll(_: UIScrollView) {
        self.scrollPositionQueue.add(self, #selector(self.scrollPositionDidChange))
    }

    // MARK: Reloading

    func queueReloadAvailableCells() {
        CoalescingQueue.standard.add(self, #selector(self.reloadAllVisibleCells))
    }

    @objc
    func reloadAllVisibleCells() {
        let visibleArticles = self.tableView.indexPathsForVisibleRows!
            .compactMap { self.dataSource.itemIdentifier(for: $0) }
        self.reloadCells(visibleArticles)
    }

    private func reloadCells(_ articles: [Article]) {
        var snapshot = self.dataSource.snapshot()
        snapshot.reloadItems(articles)
        self.dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.restoreSelectionIfNecessary(adjustScroll: false)
        }
    }

    // MARK: - Private

    func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
        assert(self.coordinator != nil)
        self.coordinator?.searchArticles(searchString, searchScope)
    }

    private func configureToolbar() {
        if traitCollection.userInterfaceIdiom == .phone {
            toolbarItems?.insert(.flexibleSpace(), at: 1)
            toolbarItems?.insert(navigationItem.searchBarPlacementBarButtonItem, at: 2)
        }
    }

    private func resetUI(resetScroll: Bool) {
        switch self.timelineDefaultReadFilterType {
        case .none, .read:
            navigationItem.rightBarButtonItem = self.filterButton
            navigationItem.rightBarButtonItem?.isEnabled = true
        case .alwaysRead:
            navigationItem.rightBarButtonItem = nil
        }

        if self.isReadArticlesFiltered {
            self.filterButton.style = .prominent
            self.filterButton.tintColor = Assets.Colors.primaryAccent
            self.filterButton.accLabelText = NSLocalizedString(
                "Selected - Filter Read Articles",
                comment: "Selected - Filter Read Articles"
            )
        } else {
            self.filterButton.style = .plain
            self.filterButton.tintColor = nil
            self.filterButton.accLabelText = NSLocalizedString("Filter Read Articles", comment: "Filter Read Articles")
        }

        self.tableView.selectRow(at: nil, animated: false, scrollPosition: .top)

        if resetScroll {
            let snapshot = self.dataSource.snapshot()
            if snapshot.sectionIdentifiers.count > 0, snapshot.itemIdentifiers(inSection: 0).count > 0 {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            }
        }

        self.updateToolbar()
    }

    func updateToolbar() {
        self.markAllAsReadButton.isEnabled = self.isTimelineUnreadAvailable
        self.firstUnreadButton.isEnabled = self.isTimelineUnreadAvailable

        if self.isRootSplitCollapsed {
            if let toolbarItems, toolbarItems.last != firstUnreadButton {
                var items = toolbarItems
                items.append(self.firstUnreadButton)
                setToolbarItems(items, animated: false)
            }
        } else {
            if let toolbarItems, toolbarItems.last == firstUnreadButton {
                let items = Array(toolbarItems[0..<toolbarItems.count - 1])
                setToolbarItems(items, animated: false)
            }
        }
    }

    private func applyChanges(animated: Bool, completion: (() -> Void)? = nil) {
        if (self.articles?.count ?? 0) == 0 {
            self.tableView.rowHeight = self.tableView.estimatedRowHeight
        } else {
            self.tableView.rowHeight = UITableView.automaticDimension
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, Article>()
        snapshot.appendSections([0])
        snapshot.appendItems(self.articles ?? ArticleArray(), toSection: 0)

        self.dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.restoreSelectionIfNecessary(adjustScroll: false)
            completion?()
        }
    }

    private func makeDataSource() -> UITableViewDiffableDataSource<Int, Article> {
        let dataSource: UITableViewDiffableDataSource<Int, Article> =
            MainTimelineDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, article in
                let cellData = self!.configure(article: article)
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "MainTimelineIconFeedCell",
                    for: indexPath
                ) as! MainTimelineIconFeedCell
                cell.cellData = cellData
                return cell
            })
        dataSource.defaultRowAnimation = .middle
        return dataSource
    }

    @discardableResult
    func configure(article: Article) -> MainTimelineCellData {
        let iconImage = self.iconImageFor(article)
        let showFeedNames = self.coordinator?.showFeedNames ?? ShowFeedName.none
        let showIcon = self.showIcons && iconImage != nil
        let isCompact = traitCollection.horizontalSizeClass == .compact
        let cellData = MainTimelineCellData(
            article: article,
            showFeedName: showFeedNames,
            feedName: article.feed?.nameForDisplay,
            byline: article.byline(),
            iconImage: iconImage,
            showIcon: showIcon,
            numberOfLines: isCompact ? 2 : 3,
            iconSize: isCompact ? .medium : .large
        )
        return cellData
    }

    func iconImageFor(_ article: Article) -> IconImage? {
        guard self.showIcons else { return nil }
        return article.iconImage()
    }
}

// MARK: - MainTimelineDataSource

final class MainTimelineDataSource<SectionIdentifierType, ItemIdentifierType>: UITableViewDiffableDataSource<
    SectionIdentifierType,
    ItemIdentifierType
> where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
    override func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        true
    }
}
