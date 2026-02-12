//
//  ImageHeaderView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(iOS)

import UIKit

final class ImageHeaderView: UITableViewHeaderFooterView {
    static let rowHeight = CGFloat(integerLiteral: 88)

    let imageView = UIImageView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    func commonInit() {
        self.imageView.tintColor = UIColor.label
        self.imageView.contentMode = .scaleAspectFit
        addSubview(self.imageView)
    }

    override func layoutSubviews() {
        let x = (bounds.width - 48.0) / 2
        let y = (bounds.height - 48.0) / 2
        self.imageView.frame = CGRect(x: x, y: y, width: 48.0, height: 48.0)
    }
}

#endif
