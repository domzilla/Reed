//
//  PseudoFeed.swift
//  Reed
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

@preconcurrency import RSCore
import UIKit

@MainActor
protocol PseudoFeed: AnyObject, SidebarItem, SmallIconProvider {}
