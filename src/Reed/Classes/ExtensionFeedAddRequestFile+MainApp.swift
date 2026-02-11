//
//  ExtensionFeedAddRequestFile+MainApp.swift
//  Reed
//
//  Main app extension for ExtensionFeedAddRequestFile that handles processing feed add requests.
//

import DZFoundation
import Foundation

extension ExtensionFeedAddRequestFile {
    /// Starts observing for feed add requests from the Share Extension.
    @MainActor
    func start() {
        let alreadyStarted = didStart.withLock { started in
            if started {
                return true
            }
            started = true
            return false
        }

        guard !alreadyStarted else {
            assertionFailure("start() called when already active")
            return
        }

        NSFileCoordinator.addFilePresenter(self)
        self.process()
    }

    /// Registers file presenter when app returns to foreground.
    @MainActor
    func resume() {
        NSFileCoordinator.addFilePresenter(self)
        self.process()
    }

    /// Removes file presenter when app enters background.
    func suspend() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// Called when the shared file changes.
    func presentedItemDidChange() {
        Task { @MainActor in
            self.process()
        }
    }

    /// Reads pending feed add requests and processes them.
    @MainActor
    private func process() {
        let decoder = PropertyListDecoder()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let errorPointer: NSErrorPointer = nil
        let fileCoordinator = NSFileCoordinator(filePresenter: self)
        let fileURL = URL(fileURLWithPath: Self.filePath)

        var requests: [ExtensionFeedAddRequest]? = nil

        fileCoordinator.coordinate(
            writingItemAt: fileURL,
            options: [.forMerging],
            error: errorPointer,
            byAccessor: { url in
                do {
                    if
                        let fileData = try? Data(contentsOf: url),
                        let decodedRequests = try? decoder.decode([ExtensionFeedAddRequest].self, from: fileData)
                    {
                        requests = decodedRequests
                    }

                    // Clear the file after reading
                    let data = try encoder.encode([ExtensionFeedAddRequest]())
                    try data.write(to: url)

                } catch let error as NSError {
                    DZLog("Process from disk failed: \(error.localizedDescription)")
                }
            }
        )

        if let error = errorPointer?.pointee {
            DZLog("Process from disk coordination failed: \(error.localizedDescription)")
        }

        requests?.forEach { self.processRequest($0) }
    }

    /// Processes a single feed add request by adding it to the appropriate data store.
    @MainActor
    private func processRequest(_ request: ExtensionFeedAddRequest) {
        var destinationDataStoreID: String? = nil
        switch request.destinationContainerID {
        case let .dataStore(dataStoreID):
            destinationDataStoreID = dataStoreID
        case let .folder(dataStoreID, _):
            destinationDataStoreID = dataStoreID
        default:
            break
        }

        guard
            let dataStoreID = destinationDataStoreID,
            let dataStore = DataStoreManager.shared.existingDataStore(dataStoreID: dataStoreID) else
        {
            return
        }

        var destinationContainer: Container? = nil
        if dataStore.containerID == request.destinationContainerID {
            destinationContainer = dataStore
        } else {
            destinationContainer = dataStore.folders?.first(where: { $0.containerID == request.destinationContainerID })
        }

        guard let container = destinationContainer else { return }

        dataStore.createFeed(
            url: request.feedURL.absoluteString,
            name: request.name,
            container: container,
            validateFeed: true
        ) { _ in }
    }
}
