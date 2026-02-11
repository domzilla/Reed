//
//  FindInArticleActivity.swift
//  Reed
//
//  Created by Brian Sanders on 5/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class FindInArticleActivity: UIActivity {
    override nonisolated init() {
        super.init()
    }

    override nonisolated var activityTitle: String? {
        NSLocalizedString("Find in Article", comment: "Find in Article")
    }

    override nonisolated var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType(rawValue: AppConstants.findInArticleActivityType)
    }

    override nonisolated var activityImage: UIImage? {
        UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        )
    }

    override nonisolated class var activityCategory: UIActivity.Category {
        .action
    }

    override nonisolated func canPerform(withActivityItems _: [Any]) -> Bool {
        true
    }

    override nonisolated func prepare(withActivityItems _: [Any]) {}

    override nonisolated func perform() {
        NotificationCenter.default.post(Notification(name: .FindInArticle))
        activityDidFinish(true)
    }
}
