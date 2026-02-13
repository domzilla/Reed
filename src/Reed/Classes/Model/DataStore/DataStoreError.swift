//
//  DataStoreError.swift
//  Reed
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum DataStoreError: LocalizedError {
    case createErrorNotFound
    case createErrorAlreadySubscribed
    case opmlImportInProgress
    case invalidParameter
    case invalidResponse
    case urlNotFound
    case unknown
    case wrappedError(error: Error, dataStoreID: String, dataStoreName: String)

    var isCredentialsError: Bool {
        false
    }

    @MainActor
    static func wrapped(_ error: Error, _ dataStore: DataStore) -> DataStoreError {
        DataStoreError.wrappedError(
            error: error,
            dataStoreID: dataStore.dataStoreID,
            dataStoreName: dataStore.nameForDisplay
        )
    }

    @MainActor
    static func dataStore(from error: DataStoreError?) -> DataStore? {
        if case let .wrappedError(_, dataStoreID, _) = error {
            return DataStore.shared.existingDataStore(dataStoreID: dataStoreID)
        }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .createErrorNotFound:
            NSLocalizedString("The feed couldn't be found and can't be added.", comment: "Not found")
        case .createErrorAlreadySubscribed:
            NSLocalizedString(
                "You are already subscribed to this feed and can't add it again.",
                comment: "Already subscribed"
            )
        case .opmlImportInProgress:
            NSLocalizedString(
                "An OPML import for this data store is already running.",
                comment: "Import running"
            )
        case .invalidParameter:
            NSLocalizedString(
                "Couldn't fulfill the request due to an invalid parameter.",
                comment: "Invalid parameter"
            )
        case .invalidResponse:
            NSLocalizedString("There was an invalid response from the server.", comment: "Invalid response")
        case .urlNotFound:
            NSLocalizedString("The URL request resulted in a not found error.", comment: "URL not found")
        case .unknown:
            NSLocalizedString("Unknown error", comment: "Unknown error")
        case let .wrappedError(error, _, dataStoreName):
            unknownError(error, dataStoreName)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .createErrorNotFound:
            nil
        case .createErrorAlreadySubscribed:
            nil
        case .wrappedError:
            NSLocalizedString("Please try again later.", comment: "Try later")
        default:
            NSLocalizedString("Please try again later.", comment: "Try later")
        }
    }
}

// MARK: Private

extension DataStoreError {
    private func unknownError(_ error: Error, _ dataStoreName: String) -> String {
        let localizedText = NSLocalizedString(
            "An error occurred while processing the \"%@\" data store: %@",
            comment: "Unknown error"
        )
        return NSString.localizedStringWithFormat(
            localizedText as NSString,
            dataStoreName,
            error.localizedDescription
        ) as String
    }
}
