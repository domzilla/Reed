//
//  BinaryDiskCache.swift
//  Core
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

final nonisolated class BinaryDiskCache: Sendable {
    let folder: String
    private let mutex = Mutex(())

    init(folder: String) {
        self.folder = folder
    }

    func data(forKey key: String) throws -> Data? {
        try self.mutex.withLock { _ in
            try _data(forKey: key)
        }
    }

    func setData(_ data: Data, forKey key: String) throws {
        try self.mutex.withLock { _ in
            try _setData(data, forKey: key)
        }
    }

    func deleteData(forKey key: String) throws {
        try self.mutex.withLock { _ in
            try _deleteData(forKey: key)
        }
    }

    // Subscript doesn’t throw. Use when you can ignore errors.

    subscript(_ key: String) -> Data? {
        get {
            self.mutex.withLock { _ in
                do {
                    return try _data(forKey: key)
                } catch {}
                return nil
            }
        }

        set {
            self.mutex.withLock { _ in
                if let data = newValue {
                    do {
                        try _setData(data, forKey: key)
                    } catch {}
                } else {
                    do {
                        try _deleteData(forKey: key)
                    } catch {}
                }
            }
        }
    }
}

nonisolated extension BinaryDiskCache {
    private func _data(forKey key: String) throws -> Data? {
        let url = self.urlForKey(key)
        return try Data(contentsOf: url)
    }

    private func _setData(_ data: Data, forKey key: String) throws {
        let url = self.urlForKey(key)
        try data.write(to: url)
    }

    private func _deleteData(forKey key: String) throws {
        let url = self.urlForKey(key)
        try FileManager.default.removeItem(at: url)
    }

    private func filePath(forKey key: String) -> String {
        (self.folder as NSString).appendingPathComponent(key)
    }

    private func urlForKey(_ key: String) -> URL {
        let f = self.filePath(forKey: key)
        return URL(fileURLWithPath: f)
    }
}
