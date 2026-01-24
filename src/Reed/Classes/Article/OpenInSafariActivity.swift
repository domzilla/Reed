//
//  OpenInSafariActivity.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/9/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class OpenInBrowserActivity: UIActivity {
    override nonisolated init() {
        super.init()
    }

    private nonisolated(unsafe) var activityItems: [Any]?

    override nonisolated var activityTitle: String? {
        NSLocalizedString("Open in Browser", comment: "Open in Browser")
    }

    override nonisolated var activityImage: UIImage? {
        UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
    }

    override nonisolated var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType(rawValue: "com.rancharo.NetNewsWire-Evergreen.safari")
    }

    override nonisolated class var activityCategory: UIActivity.Category {
        .action
    }

    override nonisolated func canPerform(withActivityItems _: [Any]) -> Bool {
        true
    }

    override nonisolated func prepare(withActivityItems activityItems: [Any]) {
        self.activityItems = activityItems
    }

    override nonisolated func perform() {
        guard let url = activityItems?.first(where: { $0 is URL }) as? URL else {
            activityDidFinish(false)
            return
        }

        Task { @MainActor in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        activityDidFinish(true)
    }
}
