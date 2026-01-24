//
//  DataStoreMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation
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

    init(filename: String, dataStore: Account) {
        self.fileURL = URL(fileURLWithPath: filename)
        self.dataStore = dataStore
    }

    @MainActor
    func markAsDirty() {
        self.isDirty = true
    }

    @MainActor
    func load() {
        if let fileData = try? Data(contentsOf: fileURL) {
            let decoder = PropertyListDecoder()
            self.dataStore
                .metadata = (try? decoder.decode(DataStoreMetadata.self, from: fileData)) ?? DataStoreMetadata()
        }
        self.dataStore.metadata.delegate = self.dataStore
    }

    @MainActor
    func save() {
        guard !self.dataStore.isDeleted else { return }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        do {
            let data = try encoder.encode(self.dataStore.metadata)
            try data.write(to: self.fileURL)
        } catch let error as NSError {
            DZLog(
                "DataStoreMetadataFile dataStoreID: \(self.dataStore.accountID) save to disk failed: \(error.localizedDescription)"
            )
        }
    }
}

extension DataStoreMetadataFile {
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
}
