//
//  FeedMetadata.swift
//  Reed
//
//  Created by Brent Simmons on 3/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol FeedMetadataDelegate: AnyObject {
    @MainActor
    func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys)
}

final class FeedMetadata: Codable, @unchecked Sendable {
    enum CodingKeys: String, CodingKey {
        case feedID
        case homePageURL
        case iconURL
        case faviconURL
        case editedName
        case authors
        case contentHash
        case isNotifyAboutNewArticles
        case isArticleExtractorAlwaysOn
        case conditionalGetInfo
        case conditionalGetInfoDate
        case cacheControlInfo
        case externalID = "subscriptionID"
        case folderRelationship
        case lastCheckDate
    }

    var feedID: String {
        didSet {
            if self.feedID != oldValue {
                self.valueDidChange(.feedID)
            }
        }
    }

    var homePageURL: String? {
        didSet {
            if self.homePageURL != oldValue {
                self.valueDidChange(.homePageURL)
            }
        }
    }

    var iconURL: String? {
        didSet {
            if self.iconURL != oldValue {
                self.valueDidChange(.iconURL)
            }
        }
    }

    var faviconURL: String? {
        didSet {
            if self.faviconURL != oldValue {
                self.valueDidChange(.faviconURL)
            }
        }
    }

    var editedName: String? {
        didSet {
            if self.editedName != oldValue {
                self.valueDidChange(.editedName)
            }
        }
    }

    var contentHash: String? {
        didSet {
            if self.contentHash != oldValue {
                self.valueDidChange(.contentHash)
            }
        }
    }

    var isNotifyAboutNewArticles: Bool? {
        didSet {
            if self.isNotifyAboutNewArticles != oldValue {
                self.valueDidChange(.isNotifyAboutNewArticles)
            }
        }
    }

    var isArticleExtractorAlwaysOn: Bool? {
        didSet {
            if self.isArticleExtractorAlwaysOn != oldValue {
                self.valueDidChange(.isArticleExtractorAlwaysOn)
            }
        }
    }

    var authors: [Author]? {
        didSet {
            if self.authors != oldValue {
                self.valueDidChange(.authors)
            }
        }
    }

    var conditionalGetInfo: HTTPConditionalGetInfo? {
        didSet {
            if self.conditionalGetInfo != oldValue {
                self.valueDidChange(.conditionalGetInfo)
                if self.conditionalGetInfo == nil {
                    self.conditionalGetInfoDate = nil
                } else {
                    self.conditionalGetInfoDate = Date()
                }
            }
        }
    }

    var conditionalGetInfoDate: Date? {
        didSet {
            if self.conditionalGetInfoDate != oldValue {
                self.valueDidChange(.conditionalGetInfoDate)
            }
        }
    }

    var cacheControlInfo: CacheControlInfo? {
        didSet {
            if self.cacheControlInfo != oldValue {
                self.valueDidChange(.cacheControlInfo)
            }
        }
    }

    var externalID: String? {
        didSet {
            if self.externalID != oldValue {
                self.valueDidChange(.externalID)
            }
        }
    }

    // Folder Name: Sync Service Relationship ID
    var folderRelationship: [String: String]? {
        didSet {
            if self.folderRelationship != oldValue {
                self.valueDidChange(.folderRelationship)
            }
        }
    }

    /// Last time an attempt was made to read the feed.
    /// (Not necessarily a successful attempt.)
    var lastCheckDate: Date? {
        didSet {
            if self.lastCheckDate != oldValue {
                self.valueDidChange(.lastCheckDate)
            }
        }
    }

    weak var delegate: FeedMetadataDelegate?

    init(feedID: String) {
        self.feedID = feedID
    }

    func valueDidChange(_ key: CodingKeys) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.valueDidChange(self, key: key)
        }
    }
}
