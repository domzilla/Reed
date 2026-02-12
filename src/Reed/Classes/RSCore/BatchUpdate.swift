//
//  BatchUpdate.swift
//  DataModel
//
//  Created by Brent Simmons on 9/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Main thread only.

typealias BatchUpdateBlock = () -> Void

extension Notification.Name {
    /// A notification posted when a batch update completes.
    static let BatchUpdateDidPerform = Notification.Name(rawValue: "BatchUpdateDidPerform")
}

/// A class for batch updating.
@MainActor
final class BatchUpdate {
    /// The shared batch update object.
    static let shared = BatchUpdate()

    private var count = 0

    /// Is updating in progress?
    var isPerforming: Bool {
        precondition(Thread.isMainThread)
        return self.count > 0
    }

    /// Perform a batch update.
    func perform(_ batchUpdateBlock: BatchUpdateBlock) {
        precondition(Thread.isMainThread)
        incrementCount()
        batchUpdateBlock()
        decrementCount()
    }

    /// Start batch updates.
    func start() {
        precondition(Thread.isMainThread)
        incrementCount()
    }

    /// End batch updates.
    func end() {
        precondition(Thread.isMainThread)
        decrementCount()
    }
}

extension BatchUpdate {
    private func incrementCount() {
        self.count = self.count + 1
    }

    private func decrementCount() {
        self.count = self.count - 1
        if self.count < 1 {
            assert(self.count > -1, "Expected batch updates count to be 0 or greater.")
            self.count = 0
            self.postBatchUpdateDidPerform()
        }
    }

    private func postBatchUpdateDidPerform() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                NotificationCenter.default.post(name: .BatchUpdateDidPerform, object: nil, userInfo: nil)
            }
        } else {
            NotificationCenter.default.post(name: .BatchUpdateDidPerform, object: nil, userInfo: nil)
        }
    }
}
