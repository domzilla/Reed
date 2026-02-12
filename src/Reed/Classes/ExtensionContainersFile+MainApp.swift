//
//  ExtensionContainersFile+MainApp.swift
//  Reed
//
//  Main app extension for ExtensionContainersFile that handles saving.
//

import DZFoundation
import Foundation

@MainActor
extension ExtensionContainersFile {
    private static var isActive = false
    private static var isDirty = false {
        didSet {
            queueSaveToDiskIfNeeded()
        }
    }

    private static let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)

    func start() {
        guard !Self.isActive else {
            assertionFailure("start() called when already active")
            return
        }
        Self.isActive = true

        if !FileManager.default.fileExists(atPath: Self.filePath) {
            self.save()
        }

        // Track when feeds/folders change to sync with extension
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.markAsDirty),
            name: .ChildrenDidChange,
            object: nil
        )
    }

    @objc
    private func markAsDirty() {
        Self.isDirty = true
    }

    private static func queueSaveToDiskIfNeeded() {
        self.saveQueue.add(shared, #selector(saveToDiskIfNeeded))
    }

    @objc
    private func saveToDiskIfNeeded() {
        if Self.isDirty {
            Self.isDirty = false
            self.save()
        }
    }

    private func save() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let errorPointer: NSErrorPointer = nil
        let fileCoordinator = NSFileCoordinator()
        let fileURL = URL(fileURLWithPath: Self.filePath)

        fileCoordinator.coordinate(writingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { writeURL in
            do {
                let extensionDataStores = DataStore.shared.sortedActiveDataStores
                    .map { ExtensionDataStore(dataStore: $0) }
                let extensionContainers = ExtensionContainers(dataStores: extensionDataStores)
                let data = try encoder.encode(extensionContainers)
                try data.write(to: writeURL)
            } catch let error as NSError {
                DZLog("Save to disk failed: \(error.localizedDescription)")
            }
        })

        if let error = errorPointer?.pointee {
            DZLog("Save to disk coordination failed: \(error.localizedDescription)")
        }
    }
}
