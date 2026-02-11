//
//  MainTimelineDataSource.swift
//  Reed
//
//  Created by Maurice Parker on 8/30/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class MainTimelineDataSource<SectionIdentifierType, ItemIdentifierType>: UITableViewDiffableDataSource<
    SectionIdentifierType,
    ItemIdentifierType
> where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
    override func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        true
    }
}
