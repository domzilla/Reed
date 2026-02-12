//
//  UIView+RSCore.swift
//  RSCore
//
//  Created by Maurice Parker on 4/20/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

#if os(iOS)

import UIKit

extension UIView {
    func setFrameIfNotEqual(_ rect: CGRect) {
        if !self.frame.equalTo(rect) {
            self.frame = rect
        }
    }

    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

#endif
