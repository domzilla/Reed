//
//  MarkAsReadAlertController.swift
//  Reed
//
//  Created by Phil Viso on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

protocol MarkAsReadAlertControllerSourceType {}
extension CGRect: MarkAsReadAlertControllerSourceType {}
extension UIView: MarkAsReadAlertControllerSourceType {}
extension UIBarButtonItem: MarkAsReadAlertControllerSourceType {}

@MainActor
struct MarkAsReadAlertController {
    static func confirm(
        _ controller: UIViewController?,
        confirmTitle: String,
        sourceType: some MarkAsReadAlertControllerSourceType,
        cancelCompletion: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        guard let controller else {
            completion()
            return
        }

        let title = NSLocalizedString("Mark As Read", comment: "Mark As Read")
        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")

        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelCompletion?()
        }
        let markAction = UIAlertAction(title: confirmTitle, style: .default) { _ in
            completion()
        }

        alertController.addAction(markAction)
        alertController.addAction(cancelAction)

        if let barButtonItem = sourceType as? UIBarButtonItem {
            alertController.popoverPresentationController?.barButtonItem = barButtonItem
        }

        if let rect = sourceType as? CGRect {
            alertController.popoverPresentationController?.sourceRect = rect
        }

        if let view = sourceType as? UIView {
            alertController.popoverPresentationController?.sourceView = view
        }

        controller.present(alertController, animated: true)
    }
}
