//
//  AutoRefreshTimer.swift
//  Reed
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
final class AutoRefreshTimer {
    var shuttingDown = false

    private var internalTimer: Timer?
    private var lastTimedRefresh: Date?
    private let launchTime = Date()

    func fireOldTimer() {
        if let timer = internalTimer {
            if timer.fireDate < Date() {
                if AppDefaults.shared.refreshInterval != .manually {
                    self.timedRefresh(nil)
                }
            }
        }
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

        let refreshInterval = AppDefaults.shared.refreshInterval
        if refreshInterval == .manually {
            self.invalidate()
            return
        }
        let lastRefreshDate = self.lastTimedRefresh ?? self.launchTime
        let secondsToAdd = refreshInterval.inSeconds()
        var nextRefreshTime = lastRefreshDate.addingTimeInterval(secondsToAdd)
        if nextRefreshTime < Date() {
            nextRefreshTime = Date().addingTimeInterval(secondsToAdd)
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

        DataStore.shared.refreshAllWithoutWaiting()
    }
}
