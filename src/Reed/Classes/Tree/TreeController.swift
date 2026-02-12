//
//  TreeController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/29/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
protocol TreeControllerDelegate: AnyObject {
    func treeController(treeController: TreeController, childNodesFor: Node) -> [Node]?
}

typealias NodeVisitBlock = (_: Node) -> Void

@MainActor
final class TreeController {
    private weak var delegate: TreeControllerDelegate?
    let rootNode: Node

    init(delegate: TreeControllerDelegate, rootNode: Node) {
        self.delegate = delegate
        self.rootNode = rootNode
        self.rebuild()
    }

    convenience init(delegate: TreeControllerDelegate) {
        self.init(delegate: delegate, rootNode: Node.genericRootNode())
    }

    @discardableResult
    func rebuild() -> Bool {
        // Rebuild and re-sort. Return true if any changes in the entire tree.

        rebuildChildNodes(node: self.rootNode)
    }

    func visitNodes(_ visitBlock: NodeVisitBlock) {
        visitNode(self.rootNode, visitBlock)
    }

    func nodeInArrayRepresentingObject(nodes: [Node], representedObject: AnyObject, recurse: Bool = false) -> Node? {
        for oneNode in nodes {
            if oneNode.representedObject === representedObject {
                return oneNode
            }

            if recurse, oneNode.canHaveChildNodes {
                if
                    let foundNode = nodeInArrayRepresentingObject(
                        nodes: oneNode.childNodes,
                        representedObject: representedObject,
                        recurse: recurse
                    )
                {
                    return foundNode
                }
            }
        }
        return nil
    }

    func nodeInTreeRepresentingObject(_ representedObject: AnyObject) -> Node? {
        self.nodeInArrayRepresentingObject(nodes: [self.rootNode], representedObject: representedObject, recurse: true)
    }

    func normalizedSelectedNodes(_ nodes: [Node]) -> [Node] {
        // An array of nodes might include a leaf node and its parent. Remove the leaf node.

        var normalizedNodes = [Node]()

        for node in nodes {
            if !node.hasAncestor(in: nodes) {
                normalizedNodes += [node]
            }
        }

        return normalizedNodes
    }
}

extension TreeController {
    private func visitNode(_ node: Node, _ visitBlock: NodeVisitBlock) {
        visitBlock(node)
        for oneChildNode in node.childNodes {
            self.visitNode(oneChildNode, visitBlock)
        }
    }

    private func nodeArraysAreEqual(_ nodeArray1: [Node]?, _ nodeArray2: [Node]?) -> Bool {
        if nodeArray1 == nil, nodeArray2 == nil {
            return true
        }
        if nodeArray1 != nil, nodeArray2 == nil {
            return false
        }
        if nodeArray1 == nil, nodeArray2 != nil {
            return false
        }

        return nodeArray1! == nodeArray2!
    }

    private func rebuildChildNodes(node: Node) -> Bool {
        if !node.canHaveChildNodes {
            return false
        }

        var childNodesDidChange = false

        let childNodes = self.delegate?.treeController(treeController: self, childNodesFor: node) ?? [Node]()

        childNodesDidChange = !self.nodeArraysAreEqual(childNodes, node.childNodes)
        if childNodesDidChange {
            node.childNodes = childNodes
        }

        for oneChildNode in childNodes {
            if self.rebuildChildNodes(node: oneChildNode) {
                childNodesDidChange = true
            }
        }

        return childNodesDidChange
    }
}
