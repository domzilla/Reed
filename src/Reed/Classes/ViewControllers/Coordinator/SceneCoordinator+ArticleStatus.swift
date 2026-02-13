//
//  SceneCoordinator+ArticleStatus.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func markAllAsRead(_ articles: [Article], completion: (() -> Void)? = nil) {
        self.markArticlesWithUndo(articles, statusKey: .read, flag: true, completion: completion)
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
            self.markArticlesWithUndo([article], statusKey: .read, flag: true)
        }
    }

    func markAsUnreadForCurrentArticle() {
        if let article = currentArticle {
            self.markArticlesWithUndo([article], statusKey: .read, flag: false)
        }
    }

    func toggleReadForCurrentArticle() {
        if let article = currentArticle {
            self.toggleRead(article)
        }
    }

    func toggleRead(_ article: Article) {
        guard !article.status.read || article.isAvailableToMarkUnread else { return }
        self.markArticlesWithUndo([article], statusKey: .read, flag: !article.status.read)
    }

    func toggleStarredForCurrentArticle() {
        if let article = currentArticle {
            self.toggleStar(article)
        }
    }

    func toggleStar(_ article: Article) {
        self.markArticlesWithUndo([article], statusKey: .starred, flag: !article.status.starred)
    }

    func markArticlesWithUndo(
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
}
