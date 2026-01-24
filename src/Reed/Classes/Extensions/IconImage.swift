//
//  IconImage.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
import UIKit

final class IconImage: @unchecked Sendable {
    let image: UIImage
    let isSymbol: Bool
    let isBackgroundSuppressed: Bool
    let preferredColor: CGColor?

    private lazy var luminanceType: ImageLuminanceType = {
        guard let cgImage = image.cgImage else { return .regular }
        return cgImage.calculateLuminanceType() ?? .regular
    }()

    var isDark: Bool {
        self.luminanceType == .dark
    }

    var isBright: Bool {
        self.luminanceType == .bright
    }

    init(
        _ image: UIImage,
        isSymbol: Bool = false,
        isBackgroundSuppressed: Bool = false,
        preferredColor: CGColor? = nil
    ) {
        self.image = image
        self.isSymbol = isSymbol
        self.preferredColor = preferredColor
        self.isBackgroundSuppressed = isBackgroundSuppressed
    }
}

enum IconSize: Int, CaseIterable, Sendable {
    case small = 1
    case medium = 2
    case large = 3

    private static let smallDimension = CGFloat(integerLiteral: 24)
    private static let mediumDimension = CGFloat(integerLiteral: 36)
    private static let largeDimension = CGFloat(integerLiteral: 48)

    var size: CGSize {
        switch self {
        case .small:
            CGSize(width: IconSize.smallDimension, height: IconSize.smallDimension)
        case .medium:
            CGSize(width: IconSize.mediumDimension, height: IconSize.mediumDimension)
        case .large:
            CGSize(width: IconSize.largeDimension, height: IconSize.largeDimension)
        }
    }
}
