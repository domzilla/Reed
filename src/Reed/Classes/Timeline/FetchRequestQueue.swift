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
    private var pendingRequests = [FetchRequestOperation]()
    private var currentRequest: FetchRequestOperation?

    var isAnyCurrentRequest: Bool {
        if let currentRequest {
            return !currentRequest.isCanceled
        }
        return false
    }

    func cancelAllRequests() {
        precondition(Thread.isMainThread)
        self.pendingRequests.forEach { $0.isCanceled = true }
        self.currentRequest?.isCanceled = true
        self.pendingRequests = [FetchRequestOperation]()
    }

    func add(_ fetchRequestOperation: FetchRequestOperation) {
        precondition(Thread.isMainThread)
        self.pendingRequests.append(fetchRequestOperation)
        runNextRequestIfNeeded()
    }
}

extension FetchRequestQueue {
    private func runNextRequestIfNeeded() {
        precondition(Thread.isMainThread)
        self.removeCanceledAndFinishedRequests()
        guard self.currentRequest == nil, let requestToRun = pendingRequests.first else {
            return
        }

        self.currentRequest = requestToRun
        self.pendingRequests.removeFirst()
        self.currentRequest!.run { fetchRequestOperation in
            precondition(fetchRequestOperation === self.currentRequest)
            self.currentRequest = nil
            self.runNextRequestIfNeeded()
        }
    }

    private func removeCanceledAndFinishedRequests() {
        self.pendingRequests = self.pendingRequests.filter { !$0.isCanceled && !$0.isFinished }
    }
}
