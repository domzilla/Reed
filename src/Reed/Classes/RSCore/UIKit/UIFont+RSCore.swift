//
//  UIFont+RSCore.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/27/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(iOS)

import UIKit

extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            UIFont(descriptor: descriptor, size: 0) // size 0 means keep the size as it is
        } else {
            self
        }
    }

    func bold() -> UIFont {
        self.withTraits(traits: .traitBold)
    }
}

#endif
