//
//  ArticleViewController.swift
//  Reed
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
import SafariServices
import UIKit
import WebKit

final class ArticleViewController: UIViewController {
    typealias State = (windowScrollY: Int, placeholder: Bool)

    // MARK: - UI Elements

    private lazy var nextUnreadBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.nextUnread,
            style: .plain,
            target: self,
            action: #selector(self.nextUnread(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Next Unread", comment: "Next Unread")
        return item
    }()

    private lazy var prevArticleBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: self,
            action: #selector(prevArticle(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Previous Article", comment: "Previous Article")
        return item
    }()

    private lazy var nextArticleBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(nextArticle(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Next Article", comment: "Next Article")
        return item
    }()

    private lazy var readBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.circleOpen,
            style: .plain,
            target: self,
            action: #selector(self.toggleRead(_:))
        )
        return item
    }()

    private lazy var starBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.starOpen,
            style: .plain,
            target: self,
            action: #selector(self.toggleStar(_:))
        )
        return item
    }()

    private lazy var actionBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(showActivityDialog(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Share", comment: "Share")
        return item
    }()

    private lazy var searchBar: ArticleSearchBar = {
        let bar = ArticleSearchBar(frame: .zero)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isHidden = true
        return bar
    }()

    private var searchBarBottomConstraint: NSLayoutConstraint!
    private var defaultControls: [UIBarButtonItem]?

    private var pageViewController: UIPageViewController!

    private var currentWebViewController: WebViewController? {
        self.pageViewController?.viewControllers?.first as? WebViewController
    }

    weak var coordinator: SceneCoordinator!

    private let poppableDelegate = PoppableGestureRecognizerDelegate()

    var article: Article? {
        didSet {
            if let controller = currentWebViewController, controller.article != article {
                controller.setArticle(self.article)
                DispatchQueue.main.async {
                    // You have to set the view controller to clear out the UIPageViewController child controller cache.
                    // You also have to do it in an async call or you will get a strange assertion error.
                    self.pageViewController.setViewControllers(
                        [controller],
                        direction: .forward,
                        animated: false,
                        completion: nil
                    )
                }
            }
            self.updateUI()
        }
    }

    var restoreScrollPosition: Int? {
        didSet {
            if let scrollY = restoreScrollPosition {
                self.currentWebViewController?.setScrollPosition(articleWindowScrollY: scrollY)
            }
        }
    }

    var currentState: State? {
        guard let controller = currentWebViewController else { return nil }
        return State(windowScrollY: controller.windowScrollY, placeholder: false)
    }

    var restoreState: State?

    private let keyboardManager = KeyboardManager(type: .detail)
    override var keyCommands: [UIKeyCommand]? {
        self.keyboardManager.keyCommands
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Set up toolbar items
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [
            self.nextUnreadBarButtonItem,
            flexSpace,
            self.prevArticleBarButtonItem,
            self.nextArticleBarButtonItem,
            flexSpace,
            self.readBarButtonItem,
            flexSpace,
            self.starBarButtonItem,
            flexSpace,
            self.actionBarButtonItem,
        ]

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
            selector: #selector(self.contentSizeCategoryDidChange(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.willEnterForeground(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        let fullScreenTapZone = UIView()
        NSLayoutConstraint.activate([
            fullScreenTapZone.widthAnchor.constraint(equalToConstant: 150),
            fullScreenTapZone.heightAnchor.constraint(equalToConstant: 44),
        ])
        fullScreenTapZone.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(self.didTapNavigationBar)
        ))
        navigationItem.titleView = fullScreenTapZone

        // Add article navigation buttons to nav bar (up/down arrows on right side)
        navigationItem.rightBarButtonItems = [self.nextArticleBarButtonItem, self.prevArticleBarButtonItem]

        if let parentNavController = navigationController?.parent as? UINavigationController {
            self.poppableDelegate.navigationController = parentNavController
            parentNavController.interactivePopGestureRecognizer?.delegate = self.poppableDelegate
        }

        self.pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [:]
        )
        self.pageViewController.delegate = self
        self.pageViewController.dataSource = self

        // This code is to disallow paging if we scroll from the left edge.  If this code is removed
        // PoppableGestureRecognizerDelegate will allow us to both navigate back and page back at the
        // same time. That is really weird when it happens.
        let panGestureRecognizer = UIPanGestureRecognizer()
        panGestureRecognizer.delegate = self
        self.pageViewController.scrollViewInsidePageControl?.addGestureRecognizer(panGestureRecognizer)

        self.pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.pageViewController.view)
        addChild(self.pageViewController!)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.pageViewController.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.pageViewController.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: self.pageViewController.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.pageViewController.view.bottomAnchor),
        ])

        let controller: WebViewController
        if let state = restoreState {
            controller = createWebViewController(self.article, updateView: false)
            controller.windowScrollY = state.windowScrollY
        } else {
            controller = createWebViewController(self.article, updateView: true)
        }

        if let scrollY = restoreScrollPosition {
            controller.setScrollPosition(articleWindowScrollY: scrollY)
        }

        self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
        if AppDefaults.shared.logicalArticleFullscreenEnabled {
            controller.hideBars()
        }

        // Search bar
        view.addSubview(self.searchBar)
        self.searchBarBottomConstraint = self.searchBar.bottomAnchor
            .constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            self.searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self.searchBarBottomConstraint,
            self.searchBar.heightAnchor.constraint(equalToConstant: 44),
        ])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(beginFind(_:)),
            name: .FindInArticle,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(endFind(_:)),
            name: .EndFindInArticle,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIWindow.keyboardWillChangeFrameNotification,
            object: nil
        )
        self.searchBar.delegate = self
        view.bringSubviewToFront(self.searchBar)

        self.updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        let hideToolbars = AppDefaults.shared.logicalArticleFullscreenEnabled
        if hideToolbars {
            self.currentWebViewController?.hideBars()
        } else {
            self.currentWebViewController?.showBars()
        }
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)
        navigationController?.navigationBar.topItem?.subtitle = nil
        self.coordinator.isArticleViewControllerPending = false
        self.searchBar.shouldBeginEditing = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.searchBar.isHidden {
            endFind()
            self.searchBar.shouldBeginEditing = false
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        // This will animate if the show/hide bars animation is happening.
        view.layoutIfNeeded()
    }

    override func willTransition(
        to newCollection: UITraitCollection,
        with _: any UIViewControllerTransitionCoordinator
    ) {
        // We only want to show bars when rotating to horizontalSizeClass == .regular
        // (i.e., big) iPhones to resolve crash #4483.
        if traitCollection.userInterfaceIdiom == .phone, newCollection.horizontalSizeClass == .regular {
            self.currentWebViewController?.showBars()
        }
    }

    func updateUI() {
        guard let article else {
            self.nextUnreadBarButtonItem.isEnabled = false
            self.prevArticleBarButtonItem.isEnabled = false
            self.nextArticleBarButtonItem.isEnabled = false
            self.readBarButtonItem.isEnabled = false
            self.starBarButtonItem.isEnabled = false
            self.actionBarButtonItem.isEnabled = false
            return
        }

        self.nextUnreadBarButtonItem.isEnabled = self.coordinator.isAnyUnreadAvailable
        self.prevArticleBarButtonItem.isEnabled = self.coordinator.isPrevArticleAvailable
        self.nextArticleBarButtonItem.isEnabled = self.coordinator.isNextArticleAvailable
        self.readBarButtonItem.isEnabled = true
        self.starBarButtonItem.isEnabled = true

        let permalinkPresent = article.preferredLink != nil
        self.actionBarButtonItem.isEnabled = permalinkPresent

        if article.status.read {
            self.readBarButtonItem.image = Assets.Images.circleOpen
            self.readBarButtonItem.isEnabled = article.isAvailableToMarkUnread
            self.readBarButtonItem.accLabelText = NSLocalizedString(
                "Mark Article Unread",
                comment: "Mark Article Unread"
            )
        } else {
            self.readBarButtonItem.image = Assets.Images.circleClosed
            self.readBarButtonItem.isEnabled = true
            self.readBarButtonItem.accLabelText = NSLocalizedString(
                "Selected - Mark Article Unread",
                comment: "Selected - Mark Article Unread"
            )
        }

        if article.status.starred {
            self.starBarButtonItem.image = Assets.Images.starClosed
            self.starBarButtonItem.accLabelText = NSLocalizedString(
                "Selected - Star Article",
                comment: "Selected - Star Article"
            )
        } else {
            self.starBarButtonItem.image = Assets.Images.starOpen
            self.starBarButtonItem.accLabelText = NSLocalizedString("Star Article", comment: "Star Article")
        }
    }

    // MARK: Notifications

    @objc
    dynamic func unreadCountDidChange(_: Notification) {
        self.updateUI()
    }

    @objc
    func statusesDidChange(_ note: Notification) {
        guard let articleIDs = note.userInfo?[DataStore.UserInfoKey.articleIDs] as? Set<String> else {
            return
        }
        guard let article else {
            return
        }
        if articleIDs.contains(article.articleID) {
            self.updateUI()
        }
    }

    @objc
    func contentSizeCategoryDidChange(_: Notification) {
        self.currentWebViewController?.fullReload()
    }

    @objc
    func willEnterForeground(_: Notification) {
        // The toolbar will come back on you if you don't hide it again
        if AppDefaults.shared.logicalArticleFullscreenEnabled {
            self.currentWebViewController?.hideBars()
        }
    }

    // MARK: Actions

    @objc
    func didTapNavigationBar() {
        self.currentWebViewController?.hideBars()
    }

    @objc
    func showBars(_: Any) {
        self.currentWebViewController?.showBars()
    }

    @objc
    func nextUnread(_: Any) {
        self.coordinator.selectNextUnread()
    }

    @objc
    func prevArticle(_: Any) {
        self.coordinator.selectPrevArticle()
    }

    @objc
    func nextArticle(_: Any) {
        self.coordinator.selectNextArticle()
    }

    @objc
    func toggleRead(_: Any) {
        self.coordinator.toggleReadForCurrentArticle()
    }

    @objc
    func toggleStar(_: Any) {
        self.coordinator.toggleStarredForCurrentArticle()
    }

    @objc
    func showActivityDialog(_: Any) {
        self.currentWebViewController?.showActivityDialog(popOverBarButtonItem: self.actionBarButtonItem)
    }

    // MARK: Keyboard Shortcuts

    @objc
    func navigateToTimeline(_: Any?) {
        self.coordinator.navigateToTimeline()
    }

    // MARK: API

    func focus() {
        self.currentWebViewController?.focus()
    }

    func canScrollDown() -> Bool {
        self.currentWebViewController?.canScrollDown() ?? false
    }

    func canScrollUp() -> Bool {
        self.currentWebViewController?.canScrollUp() ?? false
    }

    func scrollPageDown() {
        self.currentWebViewController?.scrollPageDown()
    }

    func scrollPageUp() {
        self.currentWebViewController?.scrollPageUp()
    }

    func openInAppBrowser() {
        self.currentWebViewController?.openInAppBrowser()
    }

    func setScrollPosition(articleWindowScrollY: Int) {
        self.currentWebViewController?.setScrollPosition(articleWindowScrollY: articleWindowScrollY)
    }
}

// MARK: Find in Article

extension Notification.Name {
    public static let FindInArticle = Notification.Name("FindInArticle")
    public static let EndFindInArticle = Notification.Name("EndFindInArticle")
}

extension ArticleViewController: SearchBarDelegate {
    func searchBar(_ searchBar: ArticleSearchBar, textDidChange searchText: String) {
        self.currentWebViewController?.searchText(searchText) {
            found in
            searchBar.resultsCount = found.count

            if let index = found.index {
                searchBar.selectedResult = index + 1
            }
        }
    }

    func doneWasPressed(_: ArticleSearchBar) {
        NotificationCenter.default.post(name: .EndFindInArticle, object: nil)
    }

    func nextWasPressed(_ searchBar: ArticleSearchBar) {
        if searchBar.selectedResult < searchBar.resultsCount {
            self.currentWebViewController?.selectNextSearchResult()
            searchBar.selectedResult += 1
        }
    }

    func previousWasPressed(_ searchBar: ArticleSearchBar) {
        if searchBar.selectedResult > 1 {
            self.currentWebViewController?.selectPreviousSearchResult()
            searchBar.selectedResult -= 1
        }
    }
}

extension ArticleViewController {
    @objc
    func beginFind(_ _: Any? = nil) {
        self.searchBar.isHidden = false
        navigationController?.setToolbarHidden(true, animated: true)
        self.currentWebViewController?.additionalSafeAreaInsets.bottom = self.searchBar.frame.height
        self.searchBar.becomeFirstResponder()
    }

    @objc
    func endFind(_ _: Any? = nil) {
        self.searchBar.resignFirstResponder()
        self.searchBar.isHidden = true
        navigationController?.setToolbarHidden(false, animated: true)
        self.currentWebViewController?.additionalSafeAreaInsets.bottom = 0
        self.currentWebViewController?.endSearch()
    }

    @objc
    func keyboardWillChangeFrame(_ notification: Notification) {
        if
            !self.searchBar.isHidden,
            let duration = notification.userInfo?[UIWindow.keyboardAnimationDurationUserInfoKey] as? Double,
            let curveRaw = notification.userInfo?[UIWindow.keyboardAnimationCurveUserInfoKey] as? UInt,
            let frame = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect
        {
            let curve = UIView.AnimationOptions(rawValue: curveRaw)
            let newHeight = view.safeAreaLayoutGuide.layoutFrame.maxY - frame.minY
            self.currentWebViewController?.additionalSafeAreaInsets.bottom = newHeight + self.searchBar.frame
                .height + 10
            self.searchBarBottomConstraint.constant = newHeight
            UIView.animate(withDuration: duration, delay: 0, options: curve, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
}

// MARK: UIPageViewControllerDataSource

extension ArticleViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    )
        -> UIViewController?
    {
        guard
            let webViewController = viewController as? WebViewController,
            let currentArticle = webViewController.article,
            let article = coordinator.findPrevArticle(currentArticle) else
        {
            return nil
        }
        return createWebViewController(article)
    }

    func pageViewController(
        _: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    )
        -> UIViewController?
    {
        guard
            let webViewController = viewController as? WebViewController,
            let currentArticle = webViewController.article,
            let article = coordinator.findNextArticle(currentArticle) else
        {
            return nil
        }
        return createWebViewController(article)
    }
}

// MARK: UIPageViewControllerDelegate

extension ArticleViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard finished, completed else { return }
        guard let article = currentWebViewController?.article else { return }

        self.coordinator.selectArticle(article, animations: [.select, .scroll, .navigation])

        previousViewControllers.compactMap { $0 as? WebViewController }.forEach { $0.stopWebViewActivity() }
    }
}

// MARK: UIGestureRecognizerDelegate

extension ArticleViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    )
        -> Bool
    {
        let point = gestureRecognizer.location(in: nil)
        if point.x > 40 {
            return true
        }
        return false
    }
}

// MARK: Private

extension ArticleViewController {
    private func createWebViewController(_ article: Article?, updateView: Bool = true) -> WebViewController {
        let controller = WebViewController()
        controller.coordinator = self.coordinator
        controller.setArticle(article, updateView: updateView)
        return controller
    }
}
