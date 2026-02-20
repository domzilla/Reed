//
//  BaseArticleViewController.swift
//  Reed
//
//  Created by Dominic Rodemer on 20/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

class BaseArticleViewController: UIViewController {
    // MARK: - Properties

    weak var coordinator: SceneCoordinator!

    var article: Article?

    var currentWebViewController: WebViewController? { nil }

    // MARK: - UI Elements

    private(set) lazy var readBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.circleOpen,
            style: .plain,
            target: self,
            action: #selector(self.toggleRead(_:))
        )
        return item
    }()

    private(set) lazy var starBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.starOpen,
            style: .plain,
            target: self,
            action: #selector(self.toggleStar(_:))
        )
        return item
    }()

    private(set) lazy var actionBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(self.showActivityDialog(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Share", comment: "Share")
        return item
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.statusesDidChange(_:)),
            name: .StatusesDidChange,
            object: nil
        )
    }

    // MARK: - UI Updates

    func updateUI() {
        guard let article else {
            self.readBarButtonItem.isEnabled = false
            self.starBarButtonItem.isEnabled = false
            self.actionBarButtonItem.isEnabled = false
            return
        }

        self.readBarButtonItem.isEnabled = true
        self.starBarButtonItem.isEnabled = true
        self.actionBarButtonItem.isEnabled = article.preferredLink != nil

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
            self.starBarButtonItem.accLabelText = NSLocalizedString(
                "Star Article",
                comment: "Star Article"
            )
        }
    }

    // MARK: - Actions

    @objc
    func toggleRead(_: Any) {
        guard let article else { return }
        self.coordinator.toggleRead(article)
    }

    @objc
    func toggleStar(_: Any) {
        guard let article else { return }
        self.coordinator.toggleStar(article)
    }

    @objc
    func showActivityDialog(_: Any) {
        self.currentWebViewController?.showActivityDialog(popOverBarButtonItem: self.actionBarButtonItem)
    }

    // MARK: - Notifications

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
}
