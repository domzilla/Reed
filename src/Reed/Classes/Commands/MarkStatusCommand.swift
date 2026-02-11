//
//  MarkStatusCommand.swift
//  Reed
//
//  Created by Brent Simmons on 10/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

// Mark articles read/unread, starred/unstarred, deleted/undeleted.

@MainActor
final class MarkStatusCommand: UndoableCommand {
    let undoActionName: String
    let redoActionName: String
    let articles: Set<Article>
    let undoManager: UndoManager
    let flag: Bool
    let statusKey: ArticleStatus.Key
    var completion: (() -> Void)?

    init?(
        initialArticles: [Article],
        statusKey: ArticleStatus.Key,
        flag: Bool,
        undoManager: UndoManager,
        completion: (() -> Void)? = nil
    ) {
        // Filter out articles that already have the desired status or can't be marked.
        let articlesToMark = MarkStatusCommand.filteredArticles(initialArticles, statusKey, flag)
        if articlesToMark.isEmpty {
            completion?()
            return nil
        }
        self.articles = Set(articlesToMark)

        self.flag = flag
        self.statusKey = statusKey
        self.undoManager = undoManager
        self.completion = completion

        let actionName = MarkStatusCommand.actionName(statusKey, flag)
        self.undoActionName = actionName
        self.redoActionName = actionName
    }

    convenience init?(
        initialArticles: [Article],
        markingRead: Bool,
        undoManager: UndoManager,
        completion: (() -> Void)? = nil
    ) {
        self.init(
            initialArticles: initialArticles,
            statusKey: .read,
            flag: markingRead,
            undoManager: undoManager,
            completion: completion
        )
    }

    convenience init?(
        initialArticles: [Article],
        markingStarred: Bool,
        undoManager: UndoManager,
        completion: (() -> Void)? = nil
    ) {
        self.init(
            initialArticles: initialArticles,
            statusKey: .starred,
            flag: markingStarred,
            undoManager: undoManager,
            completion: completion
        )
    }

    func perform() {
        mark(self.statusKey, self.flag)
        registerUndo()
    }

    func undo() {
        mark(self.statusKey, !self.flag)
        registerRedo()
    }
}

@MainActor
extension MarkStatusCommand {
    private func mark(_ statusKey: ArticleStatus.Key, _ flag: Bool) {
        markArticles(self.articles, statusKey: statusKey, flag: flag, completion: self.completion)
        self.completion = nil
    }

    private static let markReadActionName = NSLocalizedString("Mark Read", comment: "command")
    private static let markUnreadActionName = NSLocalizedString("Mark Unread", comment: "command")
    private static let markStarredActionName = NSLocalizedString("Mark Starred", comment: "command")
    private static let markUnstarredActionName = NSLocalizedString("Mark Unstarred", comment: "command")

    fileprivate static func actionName(_ statusKey: ArticleStatus.Key, _ flag: Bool) -> String {
        switch statusKey {
        case .read:
            flag ? self.markReadActionName : self.markUnreadActionName
        case .starred:
            flag ? self.markStarredActionName : self.markUnstarredActionName
        }
    }

    fileprivate static func filteredArticles(
        _ articles: [Article],
        _ statusKey: ArticleStatus.Key,
        _ flag: Bool
    )
        -> [Article]
    {
        articles.filter { article in
            guard article.status.boolStatus(forKey: statusKey) != flag else { return false }
            guard statusKey == .read else { return true }
            guard !article.status.read || article.isAvailableToMarkUnread else { return false }
            return true
        }
    }
}
