//
//  ExtensionContainers+Account.swift
//  NetNewsWire-iOS
//
//  Extensions for ExtensionContainers that use main app types.
//

import Foundation

extension ExtensionAccount {
	@MainActor init(account: Account) {
		self.name = account.nameForDisplay
		self.accountID = account.accountID
		self.type = account.type
		self.disallowFeedInRootFolder = account.behaviors.contains(.disallowFeedInRootFolder)
		self.containerID = account.containerID
		self.folders = account.sortedFolders?.map { ExtensionFolder(folder: $0) } ?? [ExtensionFolder]()
	}
}

extension ExtensionFolder {
	@MainActor init(folder: Folder) {
		self.accountName = folder.account?.nameForDisplay ?? ""
		self.accountID = folder.account?.accountID ?? ""
		self.name = folder.nameForDisplay
		self.containerID = folder.containerID
	}
}
