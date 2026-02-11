//
//  MainFeedRowIdentifier.swift
//  Reed
//
//  Created by Maurice Parker on 10/20/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

final class MainFeedRowIdentifier: NSObject, NSCopying {
    var indexPath: IndexPath

    init(indexPath: IndexPath) {
        self.indexPath = indexPath
    }

    func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
