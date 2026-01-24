//
//  TitleActivityItemSource.swift
//  NetNewsWire-iOS
//
//  Created by Martin Hartl on 01/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

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
