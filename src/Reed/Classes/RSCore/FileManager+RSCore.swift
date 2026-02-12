//
//  FileManager+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension FileManager {
    /// Returns whether a path refers to a folder.
    ///
    /// - Parameter path: The file path to check.
    ///
    /// - Returns: `true` if the path refers to a folder; otherwise `false`.

    func isFolder(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
            return values.isDirectory ?? false
        }

        return false
    }
}
