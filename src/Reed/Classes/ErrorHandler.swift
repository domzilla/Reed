//
//  ErrorHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import os
import RSCore
import UIKit

struct ErrorHandler: Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ErrorHandler")

    nonisolated static func present(_ viewController: UIViewController) -> @Sendable (Error) -> Void {
        { [weak viewController] error in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active {
                    viewController?.presentError(error)
                } else {
                    ErrorHandler.log(error)
                }
            }
        }
    }

    nonisolated static func log(_ error: Error) {
        self.logger.error("\(error.localizedDescription)")
    }
}
