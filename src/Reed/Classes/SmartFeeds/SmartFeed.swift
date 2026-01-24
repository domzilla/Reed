//
//  SmartFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import RSCore

@MainActor
final class SmartFeed: PseudoFeed {
    var account: Account?

    var defaultReadFilterType: ReadFilterType {
        .none
    }

    var sidebarItemID: SidebarItemIdentifier? {
        self.delegate.sidebarItemID
    }

    var nameForDisplay: String {
        self.delegate.nameForDisplay
    }

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

    var smallIcon: IconImage? {
        self.delegate.smallIcon
    }

    private let delegate: SmartFeedDelegate
    private var unreadCounts = [String: Int]()

    init(delegate: SmartFeedDelegate) {
        self.delegate = delegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        queueFetchUnreadCounts() // Fetch unread count at startup
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if note.object is AppDelegate {
            queueFetchUnreadCounts()
        }
    }

    @objc
    func fetchUnreadCounts() {
        let activeAccounts = AccountManager.shared.activeAccounts

        // Remove any accounts that are no longer active or have been deleted
        let activeAccountIDs = activeAccounts.map(\.accountID)
        for accountID in self.unreadCounts.keys {
            if !activeAccountIDs.contains(accountID) {
                self.unreadCounts.removeValue(forKey: accountID)
            }
        }

        if activeAccounts.isEmpty {
            updateUnreadCount()
        } else {
            for account in activeAccounts {
                fetchUnreadCount(account: account)
            }
        }
    }
}

extension SmartFeed: ArticleFetcher {
    func fetchArticles() throws -> Set<Article> {
        try self.delegate.fetchArticles()
    }

    func fetchArticlesAsync() async throws -> Set<Article> {
        try await self.delegate.fetchArticlesAsync()
    }

    func fetchUnreadArticles() throws -> Set<Article> {
        try self.delegate.fetchUnreadArticles()
    }

    func fetchUnreadArticlesAsync() async throws -> Set<Article> {
        try await self.delegate.fetchUnreadArticlesAsync()
    }
}

extension SmartFeed {
    private func queueFetchUnreadCounts() {
        CoalescingQueue.standard.add(self, #selector(self.fetchUnreadCounts))
    }

    private func fetchUnreadCount(account: Account) {
        Task { @MainActor in
            guard let unreadCount = try? await delegate.fetchUnreadCount(account: account) else {
                return
            }
            self.unreadCounts[account.accountID] = unreadCount
            self.updateUnreadCount()
        }
    }

    private func updateUnreadCount() {
        var updatedUnreadCount = 0
        for account in AccountManager.shared.activeAccounts {
            if let oneUnreadCount = unreadCounts[account.accountID] {
                updatedUnreadCount += oneUnreadCount
            }
        }

        self.unreadCount = updatedUnreadCount
    }
}
