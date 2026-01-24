//
//  RootSplitViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class RootSplitViewController: UISplitViewController {
    var coordinator: SceneCoordinator!

    // MARK: - Initialization

    init() {
        super.init(style: .tripleColumn)
        self.configureDefaults()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init() instead")
    }

    private func configureDefaults() {
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        primaryBackgroundStyle = .sidebar
        presentsWithGesture = true
        showsSecondaryOnlyButton = true
    }

    override var prefersStatusBarHidden: Bool {
        self.coordinator.prefersStatusBarHidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .slide
    }

    override func viewDidAppear(_: Bool) {
        self.coordinator.resetFocus()
    }

    override func show(_ column: UISplitViewController.Column) {
        guard !self.coordinator.isNavigationDisabled else { return }
        super.show(column)
    }

    // MARK: Keyboard Shortcuts

    @objc
    func scrollOrGoToNextUnread(_: Any?) {
        self.coordinator.scrollOrGoToNextUnread()
    }

    @objc
    func scrollUp(_: Any?) {
        self.coordinator.scrollUp()
    }

    @objc
    func goToPreviousUnread(_: Any?) {
        self.coordinator.selectPrevUnread()
    }

    @objc
    func nextUnread(_: Any?) {
        self.coordinator.selectNextUnread()
    }

    @objc
    func markRead(_: Any?) {
        self.coordinator.markAsReadForCurrentArticle()
    }

    @objc
    func markUnreadAndGoToNextUnread(_: Any?) {
        self.coordinator.markAsUnreadForCurrentArticle()
        self.coordinator.selectNextUnread()
    }

    @objc
    func markAllAsReadAndGoToNextUnread(_: Any?) {
        self.coordinator.markAllAsReadInTimeline {
            self.coordinator.selectNextUnread()
        }
    }

    @objc
    func markAboveAsRead(_: Any?) {
        self.coordinator.markAboveAsRead()
    }

    @objc
    func markBelowAsRead(_: Any?) {
        self.coordinator.markBelowAsRead()
    }

    @objc
    func markUnread(_: Any?) {
        self.coordinator.markAsUnreadForCurrentArticle()
    }

    @objc
    func goToPreviousSubscription(_: Any?) {
        self.coordinator.selectPrevFeed()
    }

    @objc
    func goToNextSubscription(_: Any?) {
        self.coordinator.selectNextFeed()
    }

    @objc
    func openInBrowser(_: Any?) {
        self.coordinator.showBrowserForCurrentArticle()
    }

    @objc
    func openInAppBrowser(_: Any?) {
        self.coordinator.showInAppBrowser()
    }

    @objc
    func articleSearch(_: Any?) {
        self.coordinator.showSearch()
    }

    @objc
    func addNewFeed(_: Any?) {
        self.coordinator.showAddFeed()
    }

    @objc
    func addNewFolder(_: Any?) {
        self.coordinator.showAddFolder()
    }

    @objc
    func cleanUp(_: Any?) {
        self.coordinator.cleanUp(conditional: false)
    }

    @objc
    func toggleReadFeedsFilter(_: Any?) {
        self.coordinator.toggleReadFeedsFilter()
    }

    @objc
    func toggleReadArticlesFilter(_: Any?) {
        self.coordinator.toggleReadArticlesFilter()
    }

    @objc
    func refresh(_: Any?) {
        appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
    }

    @objc
    func goToToday(_: Any?) {
        self.coordinator.selectTodayFeed()
    }

    @objc
    func goToAllUnread(_: Any?) {
        self.coordinator.selectAllUnreadFeed()
    }

    @objc
    func goToStarred(_: Any?) {
        self.coordinator.selectStarredFeed()
    }

    @objc
    func goToSettings(_: Any?) {
        self.coordinator.showSettings()
    }

    @objc
    func toggleRead(_: Any?) {
        self.coordinator.toggleReadForCurrentArticle()
    }

    @objc
    func toggleStarred(_: Any?) {
        self.coordinator.toggleStarredForCurrentArticle()
    }

    @objc
    override func toggleSidebar(_: Any?) {
        self.coordinator.toggleSidebar()
    }
}
