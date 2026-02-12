//
//  UndoableCommand.swift
//  RSCore
//
//  Created by Brent Simmons on 10/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
protocol UndoableCommand: AnyObject {
    var undoActionName: String { get }
    var redoActionName: String { get }
    var undoManager: UndoManager { get }

    func perform() // must call registerUndo()
    func undo() // must call registerRedo()
}

extension UndoableCommand {
    func registerUndo() {
        undoManager.setActionName(undoActionName)
        undoManager.registerUndo(withTarget: self) { _ in
            self.undo()
        }
    }

    func registerRedo() {
        undoManager.setActionName(redoActionName)
        undoManager.registerUndo(withTarget: self) { _ in
            self.perform()
        }
    }
}

// Useful for view controllers.

@MainActor
protocol UndoableCommandRunner: AnyObject {
    var undoableCommands: [UndoableCommand] { get set }
    var undoManager: UndoManager? { get }

    func runCommand(_ undoableCommand: UndoableCommand)
    func clearUndoableCommands()
}

@MainActor
extension UndoableCommandRunner {
    func runCommand(_ undoableCommand: UndoableCommand) {
        self.pushUndoableCommand(undoableCommand)
        undoableCommand.perform()
    }

    func pushUndoableCommand(_ undoableCommand: UndoableCommand) {
        undoableCommands += [undoableCommand]
    }

    func clearUndoableCommands() {
        // Useful, for example, when timeline is reloaded and the list of articles changes.
        // Otherwise things like Redo Mark Read are ambiguous.
        // (Do they apply to the previous articles or to the current articles?)

        guard let undoManager else {
            return
        }
        undoableCommands.forEach { undoManager.removeAllActions(withTarget: $0) }
        undoableCommands = [UndoableCommand]()
    }
}
