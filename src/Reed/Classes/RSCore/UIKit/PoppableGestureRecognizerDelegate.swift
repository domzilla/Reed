//
//  PoppableGestureRecognizerDelegate.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
// https://stackoverflow.com/a/41248703

import UIKit

final class PoppableGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        self.navigationController?.viewControllers.count ?? 0 > 1
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    )
        -> Bool
    {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
