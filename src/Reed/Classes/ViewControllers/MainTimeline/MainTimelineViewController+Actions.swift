//
//  MainTimelineViewController+Actions.swift
//  Reed
//
//  Created by Dominic Rodemer on 12/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

// MARK: - Action Builders

extension MainTimelineViewController {
    func toggleArticleReadStatusAction(_ article: Article) -> UIAction? {
        guard !article.status.read || article.isAvailableToMarkUnread else { return nil }

        let title = article.status.read ?
            NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
            NSLocalizedString("Mark as Read", comment: "Mark as Read")
        let image = article.status.read ? Assets.Images.circleClosed : Assets.Images.circleOpen

        let action = UIAction(title: title, image: image) { [weak self] _ in
            self?.toggleRead(article)
        }

        return action
    }

    func toggleArticleStarStatusAction(_ article: Article) -> UIAction {
        let title = article.status.starred ?
            NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") :
            NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
        let image = article.status.starred ? Assets.Images.starOpen : Assets.Images.starClosed

        let action = UIAction(title: title, image: image) { [weak self] _ in
            self?.toggleStar(article)
        }

        return action
    }

    func markAboveAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
        guard
            self.canMarkAboveAsRead(for: article),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
        let image = Assets.Images.markAboveAsRead
        let action = UIAction(title: title, image: image) { [weak self] _ in
            guard let self else { return }
            let alert = UIAlertController
                .markAsReadActionSheet(confirmTitle: title, source: contentView) { [weak self] in
                    self?.markAboveAsRead(article)
                }
            self.present(alert, animated: true)
        }
        return action
    }

    func markAboveAsReadAlertAction(
        _ article: Article,
        indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    )
        -> UIAlertAction?
    {
        guard
            self.canMarkAboveAsRead(for: article),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
        let cancel = {
            completion(true)
        }

        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            guard let self else {
                cancel()
                return
            }
            let alert = UIAlertController.markAsReadActionSheet(
                confirmTitle: title,
                source: contentView,
                onCancel: cancel
            ) { [weak self] in
                self?.markAboveAsRead(article)
                completion(true)
            }
            self.present(alert, animated: true)
        }
        return action
    }

    func markBelowAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
        guard
            self.canMarkBelowAsRead(for: article),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
        let image = Assets.Images.markBelowAsRead
        let action = UIAction(title: title, image: image) { [weak self] _ in
            guard let self else { return }
            let alert = UIAlertController
                .markAsReadActionSheet(confirmTitle: title, source: contentView) { [weak self] in
                    self?.markBelowAsRead(article)
                }
            self.present(alert, animated: true)
        }
        return action
    }

    func markBelowAsReadAlertAction(
        _ article: Article,
        indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    )
        -> UIAlertAction?
    {
        guard
            self.canMarkBelowAsRead(for: article),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
        let cancel = {
            completion(true)
        }

        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            guard let self else {
                cancel()
                return
            }
            let alert = UIAlertController.markAsReadActionSheet(
                confirmTitle: title,
                source: contentView,
                onCancel: cancel
            ) { [weak self] in
                self?.markBelowAsRead(article)
                completion(true)
            }
            self.present(alert, animated: true)
        }
        return action
    }

    func discloseFeedAction(_ article: Article) -> UIAction? {
        guard
            let feed = article.feed,
            !timelineFeedIsEqualTo(feed) else { return nil }

        let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
        let action = UIAction(title: title, image: Assets.Images.openInSidebar) { [weak self] _ in
            self?.discloseFeed(feed, animations: [.scroll, .navigation])
        }
        return action
    }

    func discloseFeedAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
        guard
            let feed = article.feed,
            !timelineFeedIsEqualTo(feed) else { return nil }

        let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.discloseFeed(feed, animations: [.scroll, .navigation])
            completion(true)
        }
        return action
    }

    func markAllInFeedAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
        guard let feed = article.feed else { return nil }
        guard let fetchedArticles = try? feed.fetchArticles() else {
            return nil
        }

        let articles = Array(fetchedArticles)
        guard
            articles.canMarkAllAsRead(),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let localizedMenuText = NSLocalizedString("Mark All as Read in \u{201C}%@\u{201D}", comment: "Command")
        let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String

        let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] _ in
            guard let self else { return }
            let alert = UIAlertController
                .markAsReadActionSheet(confirmTitle: title, source: contentView) { [weak self] in
                    self?.markAllAsRead(articles)
                }
            self.present(alert, animated: true)
        }
        return action
    }

    func markAllInFeedAsReadAlertAction(
        _ article: Article,
        indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    )
        -> UIAlertAction?
    {
        guard let feed = article.feed else { return nil }
        guard let fetchedArticles = try? feed.fetchArticles() else {
            return nil
        }

        let articles = Array(fetchedArticles)
        guard
            articles.canMarkAllAsRead(),
            let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else
        {
            return nil
        }

        let localizedMenuText = NSLocalizedString(
            "Mark All as Read in \u{201C}%@\u{201D}",
            comment: "Mark All as Read in Feed"
        )
        let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
        let cancel = {
            completion(true)
        }

        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            guard let self else {
                cancel()
                return
            }
            let alert = UIAlertController.markAsReadActionSheet(
                confirmTitle: title,
                source: contentView,
                onCancel: cancel
            ) { [weak self] in
                self?.markAllAsRead(articles)
                completion(true)
            }
            self.present(alert, animated: true)
        }
        return action
    }

    func copyArticleURLAction(_ article: Article) -> UIAction? {
        guard let url = article.preferredURL else { return nil }
        let title = NSLocalizedString("Copy Article URL", comment: "Copy Article URL")
        let action = UIAction(title: title, image: Assets.Images.copy) { _ in
            UIPasteboard.general.url = url
        }
        return action
    }

    func copyExternalURLAction(_ article: Article) -> UIAction? {
        guard
            let externalLink = article.externalLink, externalLink != article.preferredLink,
            let url = URL(string: externalLink) else { return nil }
        let title = NSLocalizedString("Copy External URL", comment: "Copy External URL")
        let action = UIAction(title: title, image: Assets.Images.copy) { _ in
            UIPasteboard.general.url = url
        }
        return action
    }

    func openInBrowserAction(_ article: Article) -> UIAction? {
        guard let _ = article.preferredURL else { return nil }
        let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
        let action = UIAction(title: title, image: Assets.Images.safari) { [weak self] _ in
            self?.showBrowserForArticle(article)
        }
        return action
    }

    func openInBrowserAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
        guard let _ = article.preferredURL else { return nil }

        let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.showBrowserForArticle(article)
            completion(true)
        }
        return action
    }

    func shareAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
        guard let url = article.preferredURL else { return nil }
        let title = NSLocalizedString("Share", comment: "Share")
        let action = UIAction(title: title, image: Assets.Images.share) { [weak self] _ in
            self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
        }
        return action
    }

    func shareAlertAction(
        _ article: Article,
        indexPath: IndexPath,
        completion: @escaping (Bool) -> Void
    )
        -> UIAlertAction?
    {
        guard let url = article.preferredURL else { return nil }
        let title = NSLocalizedString("Share", comment: "Share")
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            completion(true)
            self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
        }
        return action
    }

    // MARK: - Action Helpers

    func toggleRead(_ article: Article) {
        assert(self.coordinator != nil)
        self.coordinator?.toggleRead(article)
    }

    func toggleStar(_ article: Article) {
        assert(self.coordinator != nil)
        self.coordinator?.toggleStar(article)
    }

    func markAboveAsRead(_ article: Article) {
        assert(self.coordinator != nil)
        self.coordinator?.markAboveAsRead(article)
    }

    func canMarkAboveAsRead(for article: Article) -> Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.canMarkAboveAsRead(for: article) ?? false
    }

    func markBelowAsRead(_ article: Article) {
        assert(self.coordinator != nil)
        self.coordinator?.markBelowAsRead(article)
    }

    func canMarkBelowAsRead(for article: Article) -> Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.canMarkBelowAsRead(for: article) ?? false
    }

    func timelineFeedIsEqualTo(_ feed: Feed) -> Bool {
        assert(self.coordinator != nil)
        return self.coordinator?.timelineFeedIsEqualTo(feed) ?? false
    }

    func discloseFeed(_ feed: Feed, animations: Animations = []) {
        assert(self.coordinator != nil)
        self.coordinator?.discloseFeed(feed, animations: animations)
    }

    func markAllAsRead(_ articles: ArticleArray) {
        assert(self.coordinator != nil)
        self.coordinator?.markAllAsRead(articles)
    }

    func showBrowserForArticle(_ article: Article) {
        assert(self.coordinator != nil)
        self.coordinator?.showBrowserForArticle(article)
    }

    func shareDialogForTableCell(indexPath: IndexPath, url: URL, title: String?) {
        let itemSource = ArticleActivityItemSource(url: url, subject: title)
        let titleSource = TitleActivityItemSource(title: title)
        let activityViewController = UIActivityViewController(
            activityItems: [titleSource, itemSource],
            applicationActivities: nil
        )

        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        let popoverController = activityViewController.popoverPresentationController
        popoverController?.sourceView = cell
        popoverController?.sourceRect = CGRect(x: 0, y: 0, width: cell.frame.size.width, height: cell.frame.size.height)

        present(activityViewController, animated: true)
    }
}
