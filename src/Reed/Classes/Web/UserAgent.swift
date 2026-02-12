//
//  UserAgent.swift
//  Web
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated enum UserAgent {
    static func fromInfoPlist() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "UserAgent") as? String
    }

    static func headers() -> [AnyHashable: String]? {
        guard let userAgent = fromInfoPlist() else {
            return nil
        }

        return [HTTPRequestHeader.userAgent: userAgent]
    }
}
