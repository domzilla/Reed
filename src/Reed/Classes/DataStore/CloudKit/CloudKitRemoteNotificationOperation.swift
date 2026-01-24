//
//  CloudKitRemoteNotificationOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

@MainActor
final class CloudKitRemoteNotificationOperation: MainThreadOperation, @unchecked Sendable {
    private weak var feedsZone: CloudKitFeedsZone?
    private weak var articlesZone: CloudKitArticlesZone?
    private nonisolated(unsafe) var userInfo: [AnyHashable: Any]
    private static let logger = cloudKitLogger

    init(feedsZone: CloudKitFeedsZone, articlesZone: CloudKitArticlesZone, userInfo: [AnyHashable: Any]) {
        self.feedsZone = feedsZone
        self.articlesZone = articlesZone
        self.userInfo = userInfo
        super.init(name: "CloudKitRemoteNotificationOperation")
    }

    override func run() {
        guard let feedsZone, let articlesZone else {
            didComplete()
            return
        }

        Task { @MainActor in
            Self.logger.debug("iCloud: Processing remote notification")
            await feedsZone.receiveRemoteNotification(userInfo: self.userInfo)
            await articlesZone.receiveRemoteNotification(userInfo: self.userInfo)

            Self.logger.debug("iCloud: Finished processing remote notification")
            didComplete()
        }
    }
}
