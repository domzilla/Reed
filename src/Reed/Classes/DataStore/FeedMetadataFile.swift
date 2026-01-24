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

@MainActor
final class FeedMetadataFile {
    private let fileURL: URL
    private let dataStore: DataStore

    @MainActor private var isDirty = false {
        didSet {
            queueSaveToDiskIfNeeded()
        }
    }

    private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedMetadataFile")

    init(filename: String, dataStore: DataStore) {
        self.fileURL = URL(fileURLWithPath: filename)
        self.dataStore = dataStore
    }

    @MainActor
    func markAsDirty() {
        self.isDirty = true
    }

    func load() {
        if let fileData = try? Data(contentsOf: fileURL) {
            let decoder = PropertyListDecoder()
            self.dataStore
                .feedMetadata = (try? decoder.decode(DataStore.FeedMetadataDictionary.self, from: fileData)) ??
                DataStore.FeedMetadataDictionary()
        }
        self.dataStore.feedMetadata.values.forEach { $0.delegate = self.dataStore }
    }

    func save() {
        guard !self.dataStore.isDeleted else { return }

        let feedMetadata = metadataForOnlySubscribedToFeeds()

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        do {
            let data = try encoder.encode(feedMetadata)
            try data.write(to: self.fileURL)
        } catch let error as NSError {
            Self.logger.error("Save FeedMetadataFile file to disk failed: \(error.localizedDescription)")
        }
    }
}

extension FeedMetadataFile {
    @MainActor
    private func queueSaveToDiskIfNeeded() {
        self.saveQueue.add(self, #selector(self.saveToDiskIfNeeded))
    }

    @MainActor @objc
    private func saveToDiskIfNeeded() {
        if self.isDirty {
            self.isDirty = false
            self.save()
        }
    }

    private func metadataForOnlySubscribedToFeeds() -> DataStore.FeedMetadataDictionary {
        let feedIDs = self.dataStore.idToFeedDictionary.keys
        return self.dataStore.feedMetadata.filter { (_: String, metadata: FeedMetadata) -> Bool in
            return feedIDs.contains(metadata.feedID)
        }
    }
}
