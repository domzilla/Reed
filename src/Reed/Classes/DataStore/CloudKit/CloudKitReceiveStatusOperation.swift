//
//  CloudKitReceiveStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore

final class CloudKitReceiveStatusOperation: MainThreadOperation, @unchecked Sendable {
    private weak var articlesZone: CloudKitArticlesZone?

    init(articlesZone: CloudKitArticlesZone) {
        self.articlesZone = articlesZone
        super.init(name: "CloudKitReceiveStatusOperation")
    }

    @MainActor
    override func run() {
        guard let articlesZone else {
            self.didComplete()
            return
        }

        Task { @MainActor in
            defer {
                self.didComplete()
            }

            DZLog("iCloud: Refreshing article statuses")
            do {
                try await articlesZone.refreshArticles()
                DZLog("iCloud: Finished refreshing article statuses")
            } catch {
                DZLog("iCloud: Receive status error: \(error.localizedDescription)")
            }
        }
    }
}
