//
//  Node.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/21/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

private final class TopLevelRepresentedObject {}

@MainActor
final class Node: Hashable {
    weak var parent: Node?
    let representedObject: AnyObject
    var canHaveChildNodes = false
    var isGroupItem = false
    var childNodes = [Node]()
    let uniqueID: Int
    private static var incrementingID = 0

    var isRoot: Bool {
        if let _ = parent {
            return false
        }
        return true
    }

    var numberOfChildNodes: Int {
        self.childNodes.count
    }

    var indexPath: IndexPath {
        if let parent {
            let parentPath = parent.indexPath
            if let childIndex = parent.indexOfChild(self) {
                return parentPath.appending(childIndex)
            }
            preconditionFailure("A Node’s parent must contain it as a child.")
        }
        return IndexPath(index: 0) // root node
    }

    var level: Int {
        if let parent {
            return parent.level + 1
        }
        return 0
    }

    var isLeaf: Bool {
        self.numberOfChildNodes < 1
    }

    init(representedObject: AnyObject, parent: Node?) {
        precondition(Thread.isMainThread)

        self.representedObject = representedObject
        self.parent = parent

        self.uniqueID = Node.incrementingID
        Node.incrementingID += 1
    }

    class func genericRootNode() -> Node {
        let node = Node(representedObject: TopLevelRepresentedObject(), parent: nil)
        node.canHaveChildNodes = true
        return node
    }

    func existingOrNewChildNode(with representedObject: AnyObject) -> Node {
        if let node = childNodeRepresentingObject(representedObject) {
            return node
        }
        return self.createChildNode(representedObject)
    }

    func createChildNode(_ representedObject: AnyObject) -> Node {
        // Just creates — doesn’t add it.
        Node(representedObject: representedObject, parent: self)
    }

    func childAtIndex(_ index: Int) -> Node? {
        if index >= self.childNodes.count || index < 0 {
            return nil
        }
        return self.childNodes[index]
    }

    func indexOfChild(_ node: Node) -> Int? {
        self.childNodes.firstIndex { oneChildNode -> Bool in
            oneChildNode === node
        }
    }

    func childNodeRepresentingObject(_ obj: AnyObject) -> Node? {
        findNodeRepresentingObject(obj, recursively: false)
    }

    func descendantNodeRepresentingObject(_ obj: AnyObject) -> Node? {
        findNodeRepresentingObject(obj, recursively: true)
    }

    func descendantNode(where test: (Node) -> Bool) -> Node? {
        findNode(where: test, recursively: true)
    }

    func hasAncestor(in nodes: [Node]) -> Bool {
        for node in nodes {
            if node.isAncestor(of: self) {
                return true
            }
        }
        return false
    }

    func isAncestor(of node: Node) -> Bool {
        if node == self {
            return false
        }

        var nomad = node
        while true {
            guard let parent = nomad.parent else {
                return false
            }
            if parent == self {
                return true
            }
            nomad = parent
        }
    }

    class func nodesOrganizedByParent(_ nodes: [Node]) -> [Node: [Node]] {
        let nodesWithParents = nodes.filter { $0.parent != nil }
        return Dictionary(grouping: nodesWithParents, by: { $0.parent! })
    }

    class func indexSetsGroupedByParent(_ nodes: [Node]) -> [Node: IndexSet] {
        let d = self.nodesOrganizedByParent(nodes)
        let indexSetDictionary = d.mapValues { nodes -> IndexSet in
            var indexSet = IndexSet()
            if nodes.isEmpty {
                return indexSet
            }

            let parent = nodes.first!.parent!
            for node in nodes {
                if let index = parent.indexOfChild(node) {
                    indexSet.insert(index)
                }
            }

            return indexSet
        }

        return indexSetDictionary
    }

    // MARK: - Hashable

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(self.uniqueID)
    }

    // MARK: - Equatable

    nonisolated class func == (lhs: Node, rhs: Node) -> Bool {
        lhs === rhs
    }
}

@MainActor
extension [Node] {
    func representedObjects() -> [AnyObject] {
        self.map(\.representedObject)
    }
}

extension Node {
    private func findNodeRepresentingObject(_ obj: AnyObject, recursively: Bool = false) -> Node? {
        for childNode in self.childNodes {
            if childNode.representedObject === obj {
                return childNode
            }
            if recursively, let foundNode = childNode.descendantNodeRepresentingObject(obj) {
                return foundNode
            }
        }

        return nil
    }

    private func findNode(where test: (Node) -> Bool, recursively: Bool = false) -> Node? {
        for childNode in self.childNodes {
            if test(childNode) {
                return childNode
            }
            if recursively, let foundNode = childNode.findNode(where: test, recursively: recursively) {
                return foundNode
            }
        }

        return nil
    }
}
