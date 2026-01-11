//
//  FeedMetadataFile.swift
//  DataStore
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

@MainActor final class FeedMetadataFile {
	private let fileURL: URL
	private let dataStore: DataStore

	@MainActor private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}

	private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)
	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedMetadataFile")

	init(filename: String, dataStore: DataStore) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.dataStore = dataStore
	}

	@MainActor func markAsDirty() {
		isDirty = true
	}

	func load() {
		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			dataStore.feedMetadata = (try? decoder.decode(DataStore.FeedMetadataDictionary.self, from: fileData)) ?? DataStore.FeedMetadataDictionary()
		}
		dataStore.feedMetadata.values.forEach { $0.delegate = dataStore }
	}

	func save() {
		guard !dataStore.isDeleted else { return }

		let feedMetadata = metadataForOnlySubscribedToFeeds()

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(feedMetadata)
			try data.write(to: fileURL)
		} catch let error as NSError {
			Self.logger.error("Save FeedMetadataFile file to disk failed: \(error.localizedDescription)")
		}
	}
}

private extension FeedMetadataFile {

	@MainActor func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@MainActor @objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}

	private func metadataForOnlySubscribedToFeeds() -> DataStore.FeedMetadataDictionary {
		let feedIDs = dataStore.idToFeedDictionary.keys
		return dataStore.feedMetadata.filter { (feedID: String, metadata: FeedMetadata) -> Bool in
			return feedIDs.contains(metadata.feedID)
		}
	}
}
