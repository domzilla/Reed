//
//  ArticleActivityItemSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ArticleActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let subject: String?

    init(url: URL, subject: String?) {
        self.url = url
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        self.url
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        self.url
    }

    func activityViewController(
        _: UIActivityViewController,
        subjectForActivityType _: UIActivity.ActivityType?
    )
        -> String
    {
        self.subject ?? ""
    }
}
