//
//  SceneCoordinator+Display.swift
//  Reed
//

import SafariServices
import UIKit

extension SceneCoordinator {
    func resetFocus() {
        if self.currentArticle != nil {
            self.mainTimelineViewController?.focus()
        } else {
            self.mainFeedCollectionViewController?.focus()
        }
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
