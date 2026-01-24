//
//  DataStoreMetadata.swift
//  Account
//
//  Created by Brent Simmons on 3/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol DataStoreMetadataDelegate: AnyObject {
    @MainActor
    func valueDidChange(_ dataStoreMetadata: DataStoreMetadata, key: DataStoreMetadata.CodingKeys)
}

@MainActor
final class DataStoreMetadata: @MainActor Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case isActive
        case username
        case conditionalGetInfo
        case lastArticleFetchStartTime = "lastArticleFetch"
        case lastArticleFetchEndTime
        case endpointURL
        case externalID
        case performedApril2020RetentionPolicyChange
    }

    @MainActor var name: String? {
        didSet {
            if self.name != oldValue {
                self.valueDidChange(.name)
            }
        }
    }

    @MainActor var isActive: Bool = true {
        didSet {
            if self.isActive != oldValue {
                self.valueDidChange(.isActive)
            }
        }
    }

    @MainActor var username: String? {
        didSet {
            if self.username != oldValue {
                self.valueDidChange(.username)
            }
        }
    }

    @MainActor var conditionalGetInfo = [String: HTTPConditionalGetInfo]() {
        didSet {
            if self.conditionalGetInfo != oldValue {
                self.valueDidChange(.conditionalGetInfo)
            }
        }
    }

    @MainActor var lastArticleFetchStartTime: Date? {
        didSet {
            if self.lastArticleFetchStartTime != oldValue {
                self.valueDidChange(.lastArticleFetchStartTime)
            }
        }
    }

    @MainActor var lastArticleFetchEndTime: Date? {
        didSet {
            if self.lastArticleFetchEndTime != oldValue {
                self.valueDidChange(.lastArticleFetchEndTime)
            }
        }
    }

    @MainActor var endpointURL: URL? {
        didSet {
            if self.endpointURL != oldValue {
                self.valueDidChange(.endpointURL)
            }
        }
    }

    var performedApril2020RetentionPolicyChange: Bool? // No longer used.

    @MainActor var externalID: String? {
        didSet {
            if self.externalID != oldValue {
                self.valueDidChange(.externalID)
            }
        }
    }

    @MainActor weak var delegate: DataStoreMetadataDelegate?

    @MainActor
    func valueDidChange(_ key: CodingKeys) {
        self.delegate?.valueDidChange(self, key: key)
    }
}
