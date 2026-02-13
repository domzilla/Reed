//
//  ArticleActivityItemSource.swift
//  Reed
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

final class TitleActivityItemSource: NSObject, UIActivityItemSource {
    private let title: String?

    init(title: String?) {
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        self.title as Any
    }

    func activityViewController(
        _: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    )
        -> Any?
    {
        guard
            let activityType,
            let title else
        {
            return NSNull()
        }

        switch activityType.rawValue {
        case "com.omnigroup.OmniFocus3.iOS.QuickEntry",
             "com.culturedcode.ThingsiPhone.ShareExtension",
             "com.buffer.buffer.Buffer":
            return title
        default:
            return NSNull()
        }
    }
}
