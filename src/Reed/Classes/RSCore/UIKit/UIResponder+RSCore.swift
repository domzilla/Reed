//
//  UIResponder+RSCore.swift
//  RSCore
//
//  Created by Maurice Parker on 11/17/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder?

    static var isFirstResponderTextField: Bool {
        var isTextField = false
        if let firstResponder = UIResponder.currentFirstResponder {
            isTextField = firstResponder.isKind(of: UITextField.self) || firstResponder
                .isKind(of: UITextView.self) || firstResponder.isKind(of: UISearchBar.self)
        }

        return isTextField
    }

    static var currentFirstResponder: UIResponder? {
        UIResponder._currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(self.findFirstResponder(sender:)), to: nil, from: nil, for: nil)
        return UIResponder._currentFirstResponder
    }

    @objc
    func findFirstResponder(sender _: AnyObject) {
        UIResponder._currentFirstResponder = self
    }
}
