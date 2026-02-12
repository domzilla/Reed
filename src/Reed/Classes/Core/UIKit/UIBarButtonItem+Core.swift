//
//  UIBarButtonItem+Core.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/27/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UIBarButtonItem {
    @IBInspectable var accLabelText: String? {
        get {
            accessibilityLabel
        }
        set {
            accessibilityLabel = newValue
        }
    }
}
