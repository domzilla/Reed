//
//  CombinedRefreshProgress.swift
//  Reed
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

extension Notification.Name {
    public static let combinedRefreshProgressDidChange = Notification.Name("combinedRefreshProgressDidChange")
}

/// Combine the refresh progress of data stores into one place,
/// for use by refresh status view and so on.
public final class CombinedRefreshProgress {
    public private(set) var numberOfTasks = 0
    public private(set) var numberRemaining = 0
    public private(set) var numberCompleted = 0

    public var isComplete: Bool {
        !self.isStarted || self.numberRemaining < 1
    }

    var isStarted = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.refreshProgressDidChange(_:)),
            name: .DownloadProgressDidChange,
            object: nil
        )
    }

    func start() {
        reset()
        self.isStarted = true
    }

    func stop() {
        reset()
        self.isStarted = false
    }

    @MainActor @objc
    func refreshProgressDidChange(_: Notification) {
        guard self.isStarted else {
            return
        }

        var updatedNumberOfTasks = 0
        var updatedNumberRemaining = 0
        var updatedNumberCompleted = 0

        var didMakeChange = false

        let downloadProgresses = DataStore.shared.activeDataStores.map(\.refreshProgress)
        for downloadProgress in downloadProgresses {
            let progressInfo = downloadProgress.progressInfo
            updatedNumberOfTasks += progressInfo.numberOfTasks
            updatedNumberRemaining += progressInfo.numberRemaining
            updatedNumberCompleted += progressInfo.numberCompleted
        }

        if updatedNumberOfTasks > self.numberOfTasks {
            self.numberOfTasks = updatedNumberOfTasks
            didMakeChange = true
        }

        assert(updatedNumberRemaining <= self.numberOfTasks)
        updatedNumberRemaining = max(updatedNumberRemaining, self.numberRemaining)
        updatedNumberRemaining = min(updatedNumberRemaining, self.numberOfTasks)
        if updatedNumberRemaining != self.numberRemaining {
            self.numberRemaining = updatedNumberRemaining
            didMakeChange = true
        }

        assert(updatedNumberCompleted <= self.numberOfTasks)
        updatedNumberCompleted = max(updatedNumberCompleted, self.numberCompleted)
        updatedNumberCompleted = min(updatedNumberCompleted, self.numberOfTasks)
        if updatedNumberCompleted != self.numberCompleted {
            self.numberCompleted = updatedNumberCompleted
            didMakeChange = true
        }

        if didMakeChange {
            postDidChangeNotification()
        }
    }
}

extension CombinedRefreshProgress {
    private func reset() {
        let didMakeChange = self.numberOfTasks != 0 || self.numberRemaining != 0 || self.numberCompleted != 0

        self.numberOfTasks = 0
        self.numberRemaining = 0
        self.numberCompleted = 0

        if didMakeChange {
            self.postDidChangeNotification()
        }
    }

    private func postDidChangeNotification() {
        NotificationCenter.default.post(name: .combinedRefreshProgressDidChange, object: self)
    }
}
