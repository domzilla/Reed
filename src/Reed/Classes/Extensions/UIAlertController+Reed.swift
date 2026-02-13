//
//  UIAlertController+Reed.swift
//  Reed
//

import UIKit

protocol PopoverSource {}
extension CGRect: PopoverSource {}
extension UIView: PopoverSource {}
extension UIBarButtonItem: PopoverSource {}

extension UIAlertController {
    @MainActor
    static func markAsReadActionSheet(
        confirmTitle: String,
        source: some PopoverSource,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    )
        -> UIAlertController
    {
        let title = NSLocalizedString("Mark As Read", comment: "Mark As Read")
        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in
            onConfirm()
        })

        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            onCancel?()
        })

        if let barButtonItem = source as? UIBarButtonItem {
            alert.popoverPresentationController?.barButtonItem = barButtonItem
        }

        if let rect = source as? CGRect {
            alert.popoverPresentationController?.sourceRect = rect
        }

        if let view = source as? UIView {
            alert.popoverPresentationController?.sourceView = view
        }

        return alert
    }
}
