//
//  OPMLRepresentable.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@MainActor
protocol OPMLRepresentable {
    func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String
}

extension OPMLRepresentable {
    func OPMLString(indentLevel: Int) -> String {
        self.OPMLString(indentLevel: indentLevel, allowCustomAttributes: false)
    }
}
