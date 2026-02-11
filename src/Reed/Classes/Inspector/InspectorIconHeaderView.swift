//
//  InspectorIconHeaderView.swift
//  Reed
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class InspectorIconHeaderView: UITableViewHeaderFooterView {
    var iconView = IconView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    func commonInit() {
        addSubview(self.iconView)
    }

    override func layoutSubviews() {
        let x = (bounds.width - 48.0) / 2
        let y = (bounds.height - 48.0) / 2
        self.iconView.frame = CGRect(x: x, y: y, width: 48.0, height: 48.0)
    }
}
