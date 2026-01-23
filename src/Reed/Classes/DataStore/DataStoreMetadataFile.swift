//
//  DataStoreMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

final class DataStoreMetadataFile {
	private let fileURL: URL
	private let dataStore: Account

	@MainActor private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}
	private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataStoreMetadataFile")

	init(filename: String, dataStore: Account) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.dataStore = dataStore
	}

	@MainActor func markAsDirty() {
		isDirty = true
	}

	@MainActor func load() {
		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			dataStore.metadata = (try? decoder.decode(DataStoreMetadata.self, from: fileData)) ?? DataStoreMetadata()
		}
		dataStore.metadata.delegate = dataStore
	}

	@MainActor func save() {
		guard !dataStore.isDeleted else { return }

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(dataStore.metadata)
			try data.write(to: fileURL)
		} catch let error as NSError {
			Self.logger.error("DataStoreMetadataFile dataStoreID: \(self.dataStore.accountID) save to disk failed: \(error.localizedDescription)")
		}
	}

}

private extension DataStoreMetadataFile {

	@MainActor func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@MainActor @objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}
}
