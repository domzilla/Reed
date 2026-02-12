//
//  CoalescingQueue.swift
//  Core
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Use when you want to coalesce calls for something like updating visible table cells.
// Calls are uniqued. If you add a call with the same target and selector as a previous call, you’ll just get one call.
// Targets are weakly-held. If a target goes to nil, the call is not performed.
// The perform date is pushed off every time a call is added.
// Calls are FIFO.

struct QueueCall: Equatable {
    weak var target: AnyObject?
    let selector: Selector

    func perform() {
        _ = self.target?.perform(self.selector)
    }

    static func == (lhs: QueueCall, rhs: QueueCall) -> Bool {
        lhs.target === rhs.target && lhs.selector == rhs.selector
    }
}

@MainActor @objc
final class CoalescingQueue: NSObject {
    static let standard = CoalescingQueue(name: "Standard", interval: 0.05, maxInterval: 0.1)
    let name: String
    var isPaused = false
    private let interval: TimeInterval
    private let maxInterval: TimeInterval
    private var lastCallTime = Date.distantFuture
    private var timer: Timer?
    private var calls = [QueueCall]()

    nonisolated init(name: String, interval: TimeInterval = 0.05, maxInterval: TimeInterval = 2.0) {
        self.name = name
        self.interval = interval
        self.maxInterval = maxInterval
    }

    func add(_ target: AnyObject, _ selector: Selector) {
        let queueCall = QueueCall(target: target, selector: selector)
        self.add(queueCall)
        if Date().timeIntervalSince1970 - self.lastCallTime.timeIntervalSince1970 > self.maxInterval {
            self.timerDidFire(nil)
        }
    }

    func performCallsImmediately() {
        guard !self.isPaused else { return }
        let callsToMake = self.calls // Make a copy in case calls are added to the queue while performing calls.
        resetCalls()
        for call in callsToMake {
            call.perform()
        }
    }

    @objc
    func timerDidFire(_: Any?) {
        self.lastCallTime = Date()
        self.performCallsImmediately()
    }
}

extension CoalescingQueue {
    private func add(_ call: QueueCall) {
        self.restartTimer()

        if !self.calls.contains(call) {
            self.calls.append(call)
        }
    }

    private func resetCalls() {
        self.calls = [QueueCall]()
    }

    private func restartTimer() {
        self.invalidateTimer()
        self.timer = Timer.scheduledTimer(
            timeInterval: self.interval,
            target: self,
            selector: #selector(self.timerDidFire(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    private func invalidateTimer() {
        if let timer, timer.isValid {
            timer.invalidate()
        }
        timer = nil
    }
}
