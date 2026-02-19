//
//  MainTimelineViewController+Notifications.swift
//  Reed
//
//  Created by Dominic Rodemer on 12/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

// MARK: - Notification Handlers

extension MainTimelineViewController {
    @objc
    dynamic func unreadCountDidChange(_: Notification) {
        self.updateUI()
    }

    @objc
    func statusesDidChange(_ note: Notification) {
        guard
            let articleIDs = note.userInfo?[DataStore.UserInfoKey.articleIDs] as? Set<String>,
            !articleIDs.isEmpty else
        {
            return
        }

        let visibleArticles = self.tableView.indexPathsForVisibleRows!
            .compactMap { self.dataSource.itemIdentifier(for: $0) }
        let visibleUpdatedArticles = visibleArticles.filter { articleIDs.contains($0.articleID) }

        for article in visibleUpdatedArticles {
            if let indexPath = dataSource.indexPath(for: article) {
                if let cell = tableView.cellForRow(at: indexPath) as? MainTimelineIconFeedCell {
                    let cellData = configure(article: article)
                    cell.cellData = cellData
                }
            }
        }
    }

    @objc
    func feedIconDidBecomeAvailable(_ note: Notification) {
        guard let feed = note.userInfo?[AppConstants.NotificationKey.feed] as? Feed else {
            return
        }
        if let timelineFeed = self.timelineFeed as? Feed, timelineFeed == feed {
            self.updateNavigationBarIcon()
        }
        self.tableView.indexPathsForVisibleRows?.forEach { indexPath in
            guard let article = dataSource.itemIdentifier(for: indexPath) else {
                return
            }
            if article.feed == feed {
                if
                    let cell = tableView.cellForRow(at: indexPath) as? MainTimelineIconFeedCell,
                    let image = iconImageFor(article)
                {
                    cell.setIconImage(image)
                }
            }
        }
    }

    @objc
    func avatarDidBecomeAvailable(_ note: Notification) {
        guard let avatarURL = note.userInfo?[AppConstants.NotificationKey.url] as? String else {
            return
        }
        self.tableView.indexPathsForVisibleRows?.forEach { indexPath in
            guard
                let article = dataSource.itemIdentifier(for: indexPath), let authors = article.authors,
                !authors.isEmpty else
            {
                return
            }
            for author in authors {
                if
                    author.avatarURL == avatarURL,
                    let cell = tableView.cellForRow(at: indexPath) as? MainTimelineIconFeedCell,
                    let image = iconImageFor(article)
                {
                    cell.setIconImage(image)
                }
            }
        }
    }

    @objc
    func faviconDidBecomeAvailable(_: Notification) {
        self.queueReloadAvailableCells()
        self.updateNavigationBarIcon()
    }

    @objc
    func contentSizeCategoryDidChange(_: Notification) {
        self.reloadAllVisibleCells()
    }

    @objc
    func displayNameDidChange(_: Notification) {
        self.updateNavigationBarTitle(self.timelineFeed?.nameForDisplay ?? "")
    }

    @objc
    func willEnterForeground(_: Notification) {
        self.updateUI()
    }

    @objc
    func scrollPositionDidChange() {
        self.timelineMiddleIndexPath = self.tableView.middleVisibleRow()
    }
}
