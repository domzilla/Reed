//
//  UnreadCountProvider.swift
//  Reed
//
//  Created by Brent Simmons on 4/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let UnreadCountDidInitialize = Notification.Name("UnreadCountDidInitialize")
    static let UnreadCountDidChange = Notification.Name(rawValue: "UnreadCountDidChange")
}

@MainActor
protocol UnreadCountProvider {
    var unreadCount: Int { get }

    func postUnreadCountDidChangeNotification()
    func calculateUnreadCount(_ children: some Collection) -> Int
}

extension UnreadCountProvider {
    func postUnreadCountDidInitializeNotification() {
        NotificationCenter.default.post(name: .UnreadCountDidInitialize, object: self, userInfo: nil)
    }

    func postUnreadCountDidChangeNotification() {
        NotificationCenter.default.post(name: .UnreadCountDidChange, object: self, userInfo: nil)
    }

    func calculateUnreadCount(_ children: some Collection) -> Int {
        let updatedUnreadCount = children.reduce(0) { result, oneChild -> Int in
            if let oneUnreadCountProvider = oneChild as? UnreadCountProvider {
                return result + oneUnreadCountProvider.unreadCount
            }
            return result
        }

        return updatedUnreadCount
    }
}
