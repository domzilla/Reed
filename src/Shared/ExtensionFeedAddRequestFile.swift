//
//  ExtensionFeedAddRequestFile.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation
import Synchronization

/// Handles reading and writing feed add requests to shared App Group storage.
final class ExtensionFeedAddRequestFile: NSObject, NSFilePresenter, Sendable {
    static let shared = ExtensionFeedAddRequestFile()

    static let filePath: String = {
        let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        return containerURL!.appendingPathComponent("extension_feed_add_request.plist").path
    }()

    let operationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    var presentedItemURL: URL? {
        URL(fileURLWithPath: Self.filePath)
    }

    var presentedItemOperationQueue: OperationQueue {
        self.operationQueue
    }

    let didStart = Mutex(false)

    /// Saves a feed add request to the shared file (used by Share Extension).
    static func save(_ feedAddRequest: ExtensionFeedAddRequest) {
        let decoder = PropertyListDecoder()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let errorPointer: NSErrorPointer = nil
        let fileCoordinator = NSFileCoordinator()
        let fileURL = URL(fileURLWithPath: filePath)

        fileCoordinator.coordinate(
            writingItemAt: fileURL,
            options: [.forMerging],
            error: errorPointer,
            byAccessor: { url in
                do {
                    var requests: [ExtensionFeedAddRequest] = if
                        let fileData = try? Data(contentsOf: url),
                        let decodedRequests = try? decoder.decode([ExtensionFeedAddRequest].self, from: fileData)
                    {
                        decodedRequests
                    } else {
                        [ExtensionFeedAddRequest]()
                    }

                    requests.append(feedAddRequest)

                    let data = try encoder.encode(requests)
                    try data.write(to: url)

                } catch let error as NSError {
                    DZLog("Save to disk failed: \(error.localizedDescription)")
                }
            }
        )

        if let error = errorPointer?.pointee {
            DZLog("Save to disk coordination failed: \(error.localizedDescription)")
        }
    }
}
