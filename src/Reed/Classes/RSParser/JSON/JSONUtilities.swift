//
//  JSONUtilities.swift
//  RSParser
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum JSONUtilities {
    static func object(with data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data)
    }

    static func dictionary(with data: Data) -> JSONDictionary? {
        self.object(with: data) as? JSONDictionary
    }

    static func array(with data: Data) -> JSONArray? {
        self.object(with: data) as? JSONArray
    }
}
