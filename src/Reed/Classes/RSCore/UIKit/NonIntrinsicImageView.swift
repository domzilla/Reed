//
//  NonIntrinsicImageView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class NonIntrinsicImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

final class NonIntrinsicLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
