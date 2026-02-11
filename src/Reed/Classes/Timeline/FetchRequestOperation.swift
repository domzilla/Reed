//
//  FetchRequestOperation.swift
//  Reed
//
//  Created by Brent Simmons on 6/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

// Main thread only.
// Runs an asynchronous fetch.

typealias FetchRequestOperationResultBlock = (Set<Article>, FetchRequestOperation) -> Void

@MainActor
final class FetchRequestOperation {
    let id: Int
    let readFilterEnabledTable: [SidebarItemIdentifier: Bool]
    let resultBlock: FetchRequestOperationResultBlock
    var isCanceled = false
    var isFinished = false
    private let fetchers: [ArticleFetcher]

    init(
        id: Int,
        readFilterEnabledTable: [SidebarItemIdentifier: Bool],
        fetchers: [ArticleFetcher],
        resultBlock: @escaping FetchRequestOperationResultBlock
    ) {
        precondition(Thread.isMainThread)
        self.id = id
        self.readFilterEnabledTable = readFilterEnabledTable
        self.fetchers = fetchers
        self.resultBlock = resultBlock
    }

    @MainActor
    func run(_ completion: @escaping (FetchRequestOperation) -> Void) {
        precondition(Thread.isMainThread)
        precondition(!self.isFinished)

        Task { @MainActor in
            var didCallCompletion = false

            func callCompletionIfNeeded() {
                if !didCallCompletion {
                    didCallCompletion = true
                    completion(self)
                }
            }

            if self.isCanceled {
                callCompletionIfNeeded()
                return
            }

            if self.fetchers.isEmpty {
                self.isFinished = true
                self.resultBlock(Set<Article>(), self)
                callCompletionIfNeeded()
                return
            }

            let numberOfFetchers = self.fetchers.count
            var fetchersReturned = 0
            var fetchedArticles = Set<Article>()

            @MainActor
            func process(_ articles: Set<Article>) {
                precondition(Thread.isMainThread)
                guard !self.isCanceled else {
                    callCompletionIfNeeded()
                    return
                }

                assert(!self.isFinished)

                fetchedArticles.formUnion(articles)
                fetchersReturned += 1
                if fetchersReturned == numberOfFetchers {
                    self.isFinished = true
                    self.resultBlock(fetchedArticles, self)
                    callCompletionIfNeeded()
                }
            }

            for fetcher in self.fetchers {
                if
                    (fetcher as? SidebarItem)?
                        .readFiltered(readFilterEnabledTable: self.readFilterEnabledTable) ?? true
                {
                    if let articles = try? await fetcher.fetchUnreadArticlesAsync() {
                        process(articles)
                    }
                } else {
                    if let articles = try? await fetcher.fetchArticlesAsync() {
                        process(articles)
                    }
                }
            }
        }
    }
}
