//
//  DownloadProgress.swift
//  RSWeb
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

extension Notification.Name {
    static let DownloadProgressDidChange = Notification.Name(rawValue: "DownloadProgressDidChange")
}

final nonisolated class DownloadProgress: Hashable, Sendable {
    struct ProgressInfo: Sendable {
        let numberOfTasks: Int
        let numberCompleted: Int
        let numberRemaining: Int
    }

    private let id: Int
    private static let nextID = Mutex(0)

    private struct State {
        var numberOfTasks = 0
        var numberCompleted = 0

        var numberRemaining: Int {
            let n = self.numberOfTasks - self.numberCompleted
            assert(n >= 0)
            return n
        }

        var children = Set<DownloadProgress>()

        init(_ numberOfTasks: Int) {
            self.numberOfTasks = numberOfTasks
        }
    }

    private let state: Mutex<State>

    init(numberOfTasks: Int) {
        assert(numberOfTasks >= 0)
        self.state = Mutex(State(numberOfTasks))
        self.id = Self.autoincrementingID()
    }

    var progressInfo: ProgressInfo {
        var numberOfTasks = 0
        var numberCompleted = 0
        var numberRemaining = 0

        self.state.withLock { state in
            numberOfTasks = state.numberOfTasks
            numberCompleted = state.numberCompleted
            numberRemaining = state.numberRemaining

            for child in state.children {
                let childProgressInfo = child.progressInfo
                numberOfTasks += childProgressInfo.numberOfTasks
                numberCompleted += childProgressInfo.numberCompleted
                numberRemaining += childProgressInfo.numberRemaining
            }
        }

        return ProgressInfo(
            numberOfTasks: numberOfTasks,
            numberCompleted: numberCompleted,
            numberRemaining: numberRemaining
        )
    }

    var isComplete: Bool {
        self.state.withLock { state in
            state.numberRemaining < 1
        }
    }

    func addChild(_ childDownloadProgress: DownloadProgress) {
        precondition(self != childDownloadProgress)
        self.state.withLock { state in
            _ = state.children.insert(childDownloadProgress)
        }
    }

    func addTask() {
        self.addTasks(1)
    }

    func addTasks(_ n: Int) {
        assert(n > 0)
        self.state.withLock { state in
            state.numberOfTasks += n
        }
        postDidChangeNotification()
    }

    func completeTask() {
        self.completeTasks(1)
    }

    func completeTasks(_ tasks: Int) {
        self.state.withLock { state in
            state.numberCompleted += tasks
            assert(state.numberCompleted <= state.numberOfTasks)
        }

        postDidChangeNotification()
    }

    func completeAll() {
        self.state.withLock { state in
            state.numberCompleted = state.numberOfTasks
            for child in state.children {
                child.completeAll()
            }
        }
    }

    @discardableResult
    func reset() -> Bool {
        self.state.withLock { state in
            var didChange = false

            if state.numberOfTasks != 0 {
                state.numberOfTasks = 0
                didChange = true
            }
            if state.numberCompleted != 0 {
                state.numberCompleted = 0
                didChange = true
            }

            for child in state.children {
                didChange = child.reset()
            }

            if didChange {
                postDidChangeNotification()
            }
            return didChange
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    // MARK: - Equatable

    static func == (lhs: DownloadProgress, rhs: DownloadProgress) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Private

nonisolated extension DownloadProgress {
    private func postDidChangeNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .DownloadProgressDidChange, object: self)
        }
    }

    fileprivate static func autoincrementingID() -> Int {
        self.nextID.withLock { id in
            defer {
                id += 1
            }
            return id
        }
    }
}
