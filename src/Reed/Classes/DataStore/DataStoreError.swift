//
//  DataStoreError.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public enum DataStoreError: LocalizedError {

	case createErrorNotFound
	case createErrorAlreadySubscribed
	case opmlImportInProgress
	case invalidParameter
	case invalidResponse
	case urlNotFound
	case unknown
	case wrappedError(error: Error, dataStoreID: String, dataStoreName: String)

	public var isCredentialsError: Bool {
		if case .wrappedError(let error, _, _) = self {
			if case TransportError.httpError(let status) = error {
				return isCredentialsError(status: status)
			}
		}
		return false
	}

	@MainActor static func wrapped(_ error: Error, _ dataStore: DataStore) -> DataStoreError {
		DataStoreError.wrappedError(error: error, dataStoreID: dataStore.dataStoreID, dataStoreName: dataStore.nameForDisplay)
	}

	@MainActor public static func dataStore(from error: DataStoreError?) -> DataStore? {
		if case let .wrappedError(_, dataStoreID, _) = error {
			return DataStoreManager.shared.existingDataStore(dataStoreID: dataStoreID)
		}
		return nil
	}

	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
			return NSLocalizedString("The feed couldn't be found and can't be added.", comment: "Not found")
		case .createErrorAlreadySubscribed:
			return NSLocalizedString("You are already subscribed to this feed and can't add it again.", comment: "Already subscribed")
		case .opmlImportInProgress:
			return NSLocalizedString("An OPML import for this data store is already running.", comment: "Import running")
		case .invalidParameter:
			return NSLocalizedString("Couldn't fulfill the request due to an invalid parameter.", comment: "Invalid parameter")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "Invalid response")
		case .urlNotFound:
			return NSLocalizedString("The URL request resulted in a not found error.", comment: "URL not found")
		case .unknown:
			return NSLocalizedString("Unknown error", comment: "Unknown error")
		case .wrappedError(let error, _, let dataStoreName):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
					let localizedText = NSLocalizedString("Your \"%@\" credentials are invalid or expired.", comment: "Invalid or expired")
					return NSString.localizedStringWithFormat(localizedText as NSString, dataStoreName) as String
				} else {
					return unknownError(error, dataStoreName)
				}
			default:
				return unknownError(error, dataStoreName)
			}
		}
	}

	public var recoverySuggestion: String? {
		switch self {
		case .createErrorNotFound:
			return nil
		case .createErrorAlreadySubscribed:
			return nil
		case .wrappedError(let error, _, _):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
					return NSLocalizedString("Please update your credentials for this data store, or ensure that your data store with this service is still valid.", comment: "Expired credentials")
				} else {
					return NSLocalizedString("Please try again later.", comment: "Try later")
				}
			default:
				return NSLocalizedString("Please try again later.", comment: "Try later")
			}
		default:
			return NSLocalizedString("Please try again later.", comment: "Try later")
		}
	}
}

// MARK: Private

private extension DataStoreError {

	func unknownError(_ error: Error, _ dataStoreName: String) -> String {
		let localizedText = NSLocalizedString("An error occurred while processing the \"%@\" data store: %@", comment: "Unknown error")
		return NSString.localizedStringWithFormat(localizedText as NSString, dataStoreName, error.localizedDescription) as String
	}

	func isCredentialsError(status: Int) -> Bool {
		return status == 401  || status == 403
	}

}
