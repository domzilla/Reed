//
//  FetchRequestQueue.swift
//  Reed
//
//  Created by Brent Simmons on 6/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
final class FetchRequestQueue {
    private var currentTask: Task<Void, Never>?

    var isAnyCurrentRequest: Bool {
        guard let currentTask else { return false }
        return !currentTask.isCancelled
    }

    func cancelAllRequests() {
        self.currentTask?.cancel()
        self.currentTask = nil
    }

    func fetchArticles(
        using fetchers: [ArticleFetcher],
        readFilterEnabledTable: [SidebarItemIdentifier: Bool],
        resultHandler: @escaping (Set<Article>) -> Void
    ) {
        self.cancelAllRequests()

        self.currentTask = Task {
            var fetchedArticles = Set<Article>()

            for fetcher in fetchers {
                guard !Task.isCancelled else { return }

                let useUnread = (fetcher as? SidebarItem)?
                    .readFiltered(readFilterEnabledTable: readFilterEnabledTable) ?? true

                if useUnread {
                    if let articles = try? await fetcher.fetchUnreadArticlesAsync() {
                        fetchedArticles.formUnion(articles)
                    }
                } else {
                    if let articles = try? await fetcher.fetchArticlesAsync() {
                        fetchedArticles.formUnion(articles)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            resultHandler(fetchedArticles)
        }
    }
}
