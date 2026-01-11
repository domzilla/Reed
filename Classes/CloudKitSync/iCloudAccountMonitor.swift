//
//  iCloudAccountMonitor.swift
//  Reed
//
//  Created by Claude on 1/11/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import os.log

public extension Notification.Name {
	static let iCloudAccountStatusDidChange = Notification.Name(rawValue: "iCloudAccountStatusDidChange")
}

/// Monitors iCloud account availability and posts notifications when status changes.
/// The app uses this to determine whether CloudKit sync is available.
@MainActor
public final class iCloudAccountMonitor {
	public static let shared = iCloudAccountMonitor()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "iCloudAccountMonitor")

	public private(set) var isAvailable: Bool = false
	public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

	private let container: CKContainer

	private init() {
		let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
		self.container = CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
		setupNotificationObserver()
	}

	/// Start monitoring iCloud account status. Call this at app launch.
	public func start() {
		Task {
			await checkAccountStatus()
		}
	}

	/// Check current iCloud account status.
	public func checkAccountStatus() async {
		do {
			let status = try await container.accountStatus()
			updateStatus(status)
		} catch {
			// Don't log error - this is expected when iCloud isn't available
			Self.logger.debug("iCloud: Account status check returned error (iCloud likely not enabled)")
			updateStatus(.couldNotDetermine)
		}
	}

	/// Returns true if the given error is a recoverable iCloud error that should be queued.
	public static func isRecoverableError(_ error: Error) -> Bool {
		guard let ckError = error as? CKError else {
			// Check if it's wrapped in CloudKitError
			if let cloudKitError = error as? CloudKitError,
			   let underlyingCKError = cloudKitError.error as? CKError {
				return isRecoverableCKError(underlyingCKError)
			}
			return false
		}
		return isRecoverableCKError(ckError)
	}

	private static func isRecoverableCKError(_ ckError: CKError) -> Bool {
		switch ckError.code {
		case .notAuthenticated,
			 .networkUnavailable,
			 .networkFailure,
			 .serviceUnavailable,
			 .requestRateLimited,
			 .zoneBusy:
			return true
		default:
			return false
		}
	}

	private func setupNotificationObserver() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(accountChanged),
			name: .CKAccountChanged,
			object: nil
		)
	}

	@objc private func accountChanged(_ notification: Notification) {
		Task {
			await checkAccountStatus()
		}
	}

	private func updateStatus(_ status: CKAccountStatus) {
		let wasAvailable = isAvailable
		accountStatus = status
		isAvailable = (status == .available)

		if wasAvailable != isAvailable {
			Self.logger.info("iCloud: Account status changed to \(self.isAvailable ? "available" : "unavailable")")
			NotificationCenter.default.post(name: .iCloudAccountStatusDidChange, object: self)
		}
	}
}
