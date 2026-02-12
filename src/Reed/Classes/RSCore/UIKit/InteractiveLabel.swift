//
//  InteractiveLabel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@IBDesignable
final class InteractiveLabel: UILabel, @preconcurrency UIEditMenuInteractionDelegate {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    func commonInit() {
        let gestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPressGesture(_:))
        )
        self.addGestureRecognizer(gestureRecognizer)

        let editMenuInteraction = UIEditMenuInteraction(delegate: self)
        addInteraction(editMenuInteraction)

        self.isUserInteractionEnabled = true
    }

    @objc
    func handleLongPressGesture(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began, let recognizerView = recognizer.view else {
            return
        }

        if
            let interaction = recognizerView.interactions
                .first(where: { $0 is UIEditMenuInteraction }) as? UIEditMenuInteraction
        {
            let location = recognizer.location(in: recognizerView)
            let editMenuConfiguration = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
            interaction.presentEditMenu(with: editMenuConfiguration)
        }
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func canPerformAction(_ action: Selector, withSender _: Any?) -> Bool {
        action == #selector(UIResponderStandardEditActions.copy(_:))
    }

    override func copy(_: Any?) {
        UIPasteboard.general.string = text
    }

    // MARK: - UIEditMenuInteractionDelegate

    func editMenuInteraction(
        _: UIEditMenuInteraction,
        menuFor _: UIEditMenuConfiguration,
        suggestedActions _: [UIMenuElement]
    )
        -> UIMenu?
    {
        let copyAction = UIAction(title: "Copy", image: nil) { [weak self] _ in
            self?.copy(nil)
        }
        return UIMenu(title: "", children: [copyAction])
    }
}
