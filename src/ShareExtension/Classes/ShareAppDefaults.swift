//
//  ShareAppDefaults.swift
//  NetNewsWire iOS Share Extension
//
//  Simplified AppDefaults for Share Extension to store last selected container.
//

import Foundation

final class ShareAppDefaults: Sendable {
    static let shared = ShareAppDefaults()

    private nonisolated(unsafe) static let store: UserDefaults = .init(suiteName: SharedConstants.appGroup)!

    private init() {}

    private enum Key {
        static let addFeedAccountID = "addFeedAccountID"
        static let addFeedFolderName = "addFeedFolderName"
    }

    var addFeedAccountID: String? {
        get {
            Self.store.string(forKey: Key.addFeedAccountID)
        }
        set {
            Self.store.set(newValue, forKey: Key.addFeedAccountID)
        }
    }

    var addFeedFolderName: String? {
        get {
            Self.store.string(forKey: Key.addFeedFolderName)
        }
        set {
            Self.store.set(newValue, forKey: Key.addFeedFolderName)
        }
    }
}
