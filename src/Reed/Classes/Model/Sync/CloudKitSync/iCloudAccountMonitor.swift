//
//  iCloudAccountMonitor.swift
//  Reed
//
//  Created by Claude on 1/11/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import DZFoundation
import Foundation

extension Notification.Name {
    static let iCloudAccountStatusDidChange = Notification.Name(rawValue: "iCloudAccountStatusDidChange")
}

/// Monitors iCloud account availability and posts notifications when status changes.
/// The app uses this to determine whether CloudKit sync is available.
@MainActor
final class iCloudAccountMonitor {
    static let shared = iCloudAccountMonitor()

    private(set) var isAvailable: Bool = false
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    private let container: CKContainer
    private var notificationObserver: Any?

    private init() {
        self.container = AppConstants.cloudKitContainer
        self.setupNotificationObserver()
    }

    /// Start monitoring iCloud account status. Call this at app launch.
    func start() {
        Task {
            await self.checkAccountStatus()
        }
    }

    /// Check current iCloud account status.
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            self.updateStatus(status)
        } catch {
            // Don't log error - this is expected when iCloud isn't available
            DZLog("iCloud: Account status check returned error (iCloud likely not enabled)")
            self.updateStatus(.couldNotDetermine)
        }
    }

    /// Returns true if the given error is a recoverable iCloud error that should be queued.
    static func isRecoverableError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else {
            // Check if it's wrapped in CloudKitError
            if
                let cloudKitError = error as? CloudKitError,
                let underlyingCKError = cloudKitError.error as? CKError
            {
                return self.isRecoverableCKError(underlyingCKError)
            }
            return false
        }
        return self.isRecoverableCKError(ckError)
    }

    private static func isRecoverableCKError(_ ckError: CKError) -> Bool {
        switch ckError.code {
        case .notAuthenticated,
             .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy:
            true
        default:
            false
        }
    }

    private func setupNotificationObserver() {
        // Use block-based observer with queue: .main because .CKAccountChanged is posted
        // by CloudKit from its internal background CKProcessStateManager.notificationQueue.
        // Selector-based observers are called synchronously on the posting queue, which
        // triggers a @MainActor dispatch assertion crash in Swift 6.
        self.notificationObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.checkAccountStatus()
            }
        }
    }

    private func updateStatus(_ status: CKAccountStatus) {
        let wasAvailable = self.isAvailable
        self.accountStatus = status
        self.isAvailable = (status == .available)

        if wasAvailable != self.isAvailable {
            DZLog("iCloud: Account status changed to \(self.isAvailable ? "available" : "unavailable")")
            NotificationCenter.default.post(name: .iCloudAccountStatusDidChange, object: self)
        }
    }
}
