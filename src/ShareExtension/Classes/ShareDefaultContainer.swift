//
//  ShareDefaultContainer.swift
//  Reed
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
struct ShareDefaultContainer {
    static func defaultContainer(containers: ExtensionContainers) -> ExtensionContainer? {
        if
            let accountID = ShareAppDefaults.shared.addFeedAccountID,
            let account = containers.accounts.first(where: { $0.accountID == accountID })
        {
            if
                let folderName = ShareAppDefaults.shared.addFeedFolderName,
                let folder = account.folders.first(where: { $0.name == folderName })
            {
                folder
            } else {
                self.substituteContainerIfNeeded(account: account)
            }
        } else if let account = containers.accounts.first {
            self.substituteContainerIfNeeded(account: account)
        } else {
            nil
        }
    }

    static func saveDefaultContainer(_ container: ExtensionContainer) {
        ShareAppDefaults.shared.addFeedAccountID = container.accountID
        if let folder = container as? ExtensionFolder {
            ShareAppDefaults.shared.addFeedFolderName = folder.name
        } else {
            ShareAppDefaults.shared.addFeedFolderName = nil
        }
    }

    private static func substituteContainerIfNeeded(account: ExtensionAccount) -> ExtensionContainer? {
        if !account.disallowFeedInRootFolder {
            account
        } else {
            if let folder = account.folders.first {
                folder
            } else {
                nil
            }
        }
    }
}
