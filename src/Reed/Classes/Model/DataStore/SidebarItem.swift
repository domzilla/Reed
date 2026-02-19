//
//  SidebarItem.swift
//  Account
//
//  Created by Maurice Parker on 11/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated enum ReadFilterType: Sendable {
    case read
    case none
    case alwaysRead
}

@MainActor
protocol SidebarItem: SidebarItemIdentifiable, ArticleFetcher, DisplayNameProvider,
    UnreadCountProvider
{
    @MainActor var dataStore: DataStore? { get }
    @MainActor var defaultReadFilterType: ReadFilterType { get }
}

@MainActor
extension SidebarItem {
    func readFiltered(isReadFiltered: Bool) -> Bool {
        guard defaultReadFilterType != .alwaysRead else {
            return true
        }
        if isReadFiltered {
            return true
        } else {
            return defaultReadFilterType == .read
        }
    }
}
