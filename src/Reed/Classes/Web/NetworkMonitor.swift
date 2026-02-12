//
//  NetworkMonitor.swift
//  Web
//
//  Created by Brent Simmons on 11/4/25.
//

import Foundation
import Network
import os

final nonisolated class NetworkMonitor: Sendable {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "Web NetworkMonitor")

    private struct State: Sendable {
        var isConnected = false
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var isConnected: Bool {
        self.state.withLock { $0.isConnected }
    }

    @MainActor private var monitorIsActive = false

    private init() {
        self.monitor = NWPathMonitor()

        self.monitor.pathUpdateHandler = { [weak self] path in
            self?.updateStatus(with: path)
        }
    }

    @MainActor
    func start() {
        guard !self.monitorIsActive else {
            assertionFailure("start called when already active")
            return
        }
        self.monitorIsActive = true
        self.monitor.start(queue: self.queue)
    }

    deinit {
        monitor.cancel()
    }

    private func updateStatus(with path: NWPath) {
        self.state.withLock { state in
            state.isConnected = path.status == .satisfied
        }
    }
}
