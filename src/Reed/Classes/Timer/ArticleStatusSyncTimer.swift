//
//  ArticleStatusSyncTimer.swift
//  Reed
//
//  Created by Maurice Parker on 5/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
final class ArticleStatusSyncTimer {
    static let shared = ArticleStatusSyncTimer()

    private static let intervalSeconds = Double(120)

    var shuttingDown = false

    private var internalTimer: Timer?
    private var lastTimedRefresh: Date?
    private let launchTime = Date()

    func start() {
        self.shuttingDown = false
    }

    func stop() {
        self.shuttingDown = true
        self.invalidate()
    }

    func invalidate() {
        guard let timer = internalTimer else {
            return
        }
        if timer.isValid {
            timer.invalidate()
        }
        self.internalTimer = nil
    }

    func update() {
        guard !self.shuttingDown else {
            return
        }

        let lastRefreshDate = self.lastTimedRefresh ?? self.launchTime
        var nextRefreshTime = lastRefreshDate.addingTimeInterval(ArticleStatusSyncTimer.intervalSeconds)
        if nextRefreshTime < Date() {
            nextRefreshTime = Date().addingTimeInterval(ArticleStatusSyncTimer.intervalSeconds)
        }
        if let currentNextFireDate = internalTimer?.fireDate, currentNextFireDate == nextRefreshTime {
            return
        }

        self.invalidate()
        let timer = Timer(
            fireAt: nextRefreshTime,
            interval: 0,
            target: self,
            selector: #selector(timedRefresh(_:)),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(timer, forMode: .common)
        self.internalTimer = timer
    }

    @objc
    func timedRefresh(_: Timer?) {
        guard !self.shuttingDown else {
            return
        }

        self.lastTimedRefresh = Date()
        self.update()

        DataStore.shared.syncArticleStatusAllWithoutWaiting()
    }
}
