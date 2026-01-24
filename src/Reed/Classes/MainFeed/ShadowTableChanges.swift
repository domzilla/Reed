//
//  ShadowTableChanges.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

struct ShadowTableChanges {
    struct Move: Hashable {
        var from: Int
        var to: Int

        init(_ from: Int, _ to: Int) {
            self.from = from
            self.to = to
        }
    }

    struct RowChanges {
        var section: Int
        var deletes: Set<Int>?
        var inserts: Set<Int>?
        var reloads: Set<Int>?
        var moves: Set<ShadowTableChanges.Move>?

        var isEmpty: Bool {
            (self.deletes?.isEmpty ?? true) && (self.inserts?.isEmpty ?? true) && (self.moves?.isEmpty ?? true)
        }

        var deleteIndexPaths: [IndexPath]? {
            guard let deletes else { return nil }
            return deletes.map { IndexPath(row: $0, section: self.section) }
        }

        var insertIndexPaths: [IndexPath]? {
            guard let inserts else { return nil }
            return inserts.map { IndexPath(row: $0, section: self.section) }
        }

        var reloadIndexPaths: [IndexPath]? {
            guard let reloads else { return nil }
            return reloads.map { IndexPath(row: $0, section: self.section) }
        }

        var moveIndexPaths: [(IndexPath, IndexPath)]? {
            guard let moves else { return nil }
            return moves.map { (
                IndexPath(row: $0.from, section: self.section),
                IndexPath(row: $0.to, section: self.section)
            ) }
        }

        init(section: Int, deletes: Set<Int>?, inserts: Set<Int>?, reloads: Set<Int>?, moves: Set<Move>?) {
            self.section = section
            self.deletes = deletes
            self.inserts = inserts
            self.reloads = reloads
            self.moves = moves
        }
    }

    var deletes: Set<Int>?
    var inserts: Set<Int>?
    var moves: Set<Move>?
    var rowChanges: [RowChanges]?

    init(deletes: Set<Int>?, inserts: Set<Int>?, moves: Set<Move>?, rowChanges: [RowChanges]?) {
        self.deletes = deletes
        self.inserts = inserts
        self.moves = moves
        self.rowChanges = rowChanges
    }
}
