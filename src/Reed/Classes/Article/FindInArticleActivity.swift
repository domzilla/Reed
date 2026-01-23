//
//  FindInArticleActivity.swift
//  NetNewsWire-iOS
//
//  Created by Brian Sanders on 5/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class FindInArticleActivity: UIActivity {
	nonisolated override init() {
		super.init()
	}

	nonisolated override var activityTitle: String? {
		NSLocalizedString("Find in Article", comment: "Find in Article")
	}

	nonisolated override var activityType: UIActivity.ActivityType? {
		UIActivity.ActivityType(rawValue: "net.domzilla.reed.find")
	}

	nonisolated override var activityImage: UIImage? {
		UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
	}

	nonisolated override class var activityCategory: UIActivity.Category {
		.action
	}

	nonisolated override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		true
	}

	nonisolated override func prepare(withActivityItems activityItems: [Any]) {

	}

	nonisolated override func perform() {
		NotificationCenter.default.post(Notification(name: .FindInArticle))
		activityDidFinish(true)
	}
}
