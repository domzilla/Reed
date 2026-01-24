//
//  ExtensionContainersFile.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation

/// Handles reading and writing ExtensionContainers to shared App Group storage.
@MainActor
final class ExtensionContainersFile {
    static let shared = ExtensionContainersFile()

    static var filePath: String = {
        let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        return containerURL!.appendingPathComponent("extension_containers.plist").path
    }()

    /// Reads and decodes the shared plist file.
    static func read() -> ExtensionContainers? {
        let errorPointer: NSErrorPointer = nil
        let fileCoordinator = NSFileCoordinator()
        let fileURL = URL(fileURLWithPath: ExtensionContainersFile.filePath)
        var extensionContainers: ExtensionContainers? = nil

        fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { readURL in
            if let fileData = try? Data(contentsOf: readURL) {
                let decoder = PropertyListDecoder()
                extensionContainers = try? decoder.decode(ExtensionContainers.self, from: fileData)
            }
        })

        if let error = errorPointer?.pointee {
            DZLog("Read from disk coordination failed: \(error.localizedDescription)")
        }

        return extensionContainers
    }
}
