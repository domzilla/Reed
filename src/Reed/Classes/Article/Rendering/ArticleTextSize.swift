//
//  ArticleTextSize.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum ArticleTextSize: Int, CaseIterable, Identifiable {
    case small = 1
    case medium = 2
    case large = 3
    case xlarge = 4
    case xxlarge = 5

    var id: String { self.description() }

    var cssClass: String {
        switch self {
        case .small:
            "smallText"
        case .medium:
            "mediumText"
        case .large:
            "largeText"
        case .xlarge:
            "xLargeText"
        case .xxlarge:
            "xxLargeText"
        }
    }

    func description() -> String {
        switch self {
        case .small:
            NSLocalizedString("Small", comment: "Small")
        case .medium:
            NSLocalizedString("Medium", comment: "Medium")
        case .large:
            NSLocalizedString("Large", comment: "Large")
        case .xlarge:
            NSLocalizedString("Extra Large", comment: "X-Large")
        case .xxlarge:
            NSLocalizedString("Extra Extra Large", comment: "XX-Large")
        }
    }
}
