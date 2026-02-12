//
//  NonIntrinsicLabel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(iOS)

import UIKit

final class NonIntrinsicLabel: UILabel {
    // Prevent autolayout from messing around with our frame settings
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

#endif
