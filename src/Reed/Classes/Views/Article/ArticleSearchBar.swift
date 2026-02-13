//
//  ArticleSearchBar.swift
//  Reed
//
//  Created by Brian Sanders on 5/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

@objc @MainActor
protocol SearchBarDelegate: NSObjectProtocol {
    @objc
    optional func nextWasPressed(_ searchBar: ArticleSearchBar)
    @objc
    optional func previousWasPressed(_ searchBar: ArticleSearchBar)
    @objc
    optional func doneWasPressed(_ searchBar: ArticleSearchBar)
    @objc
    optional func searchBar(_ searchBar: ArticleSearchBar, textDidChange: String)
}

final class ArticleSearchBar: UIStackView {
    var searchField: UISearchTextField!
    var nextButton: UIButton!
    var prevButton: UIButton!
    var background: UIView!
    var shouldBeginEditing: Bool = true

    private weak var resultsLabel: UILabel!

    var resultsCount: UInt = 0 {
        didSet {
            self.updateUI()
        }
    }

    var selectedResult: UInt = 1 {
        didSet {
            self.updateUI()
        }
    }

    weak var delegate: SearchBarDelegate?

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "Exit Find", action: #selector(donePressed(_:)), input: UIKeyCommand.inputEscape)]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        layer.backgroundColor = UIColor(named: "barBackgroundColor")?.cgColor ?? UIColor.white.cgColor
        isOpaque = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self.searchField
        )
    }

    private func updateUI() {
        if self.resultsCount > 0 {
            let format = NSLocalizedString("%d of %d", comment: "Results selection and count")
            self.resultsLabel.text = String.localizedStringWithFormat(format, self.selectedResult, self.resultsCount)
        } else {
            self.resultsLabel.text = NSLocalizedString("No results", comment: "No results")
        }

        self.nextButton.isEnabled = self.selectedResult < self.resultsCount
        self.prevButton.isEnabled = self.resultsCount > 0 && self.selectedResult > 1
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        self.searchField.becomeFirstResponder()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        self.searchField.resignFirstResponder()
    }

    override var isFirstResponder: Bool {
        self.searchField.isFirstResponder
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ArticleSearchBar {
    private func commonInit() {
        isLayoutMarginsRelativeArrangement = true
        alignment = .center
        spacing = 8
        layoutMargins.left = 8
        layoutMargins.right = 8

        self.background = UIView(frame: bounds)
        self.background.backgroundColor = .systemGray5
        self.background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(self.background)

        let doneButton = UIButton()
        doneButton.setTitle(NSLocalizedString("Done", comment: "Done"), for: .normal)
        doneButton.setTitleColor(UIColor.label, for: .normal)
        doneButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        doneButton.isAccessibilityElement = true
        doneButton.addTarget(self, action: #selector(donePressed), for: .touchUpInside)
        doneButton.isEnabled = true
        addArrangedSubview(doneButton)

        let resultsLabel = UILabel()
        self.searchField = UISearchTextField()
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        self.searchField.returnKeyType = .search
        self.searchField.delegate = self

        resultsLabel.font = .systemFont(ofSize: UIFont.smallSystemFontSize)
        resultsLabel.textColor = .secondaryLabel
        resultsLabel.text = ""
        resultsLabel.textAlignment = .right
        resultsLabel.adjustsFontSizeToFitWidth = true
        self.searchField.rightView = resultsLabel
        self.searchField.rightViewMode = .always

        self.resultsLabel = resultsLabel
        addArrangedSubview(self.searchField)

        self.prevButton = UIButton(type: .system)
        self.prevButton.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        self.prevButton.accessibilityLabel = "Previous Result"
        self.prevButton.isAccessibilityElement = true
        self.prevButton.addTarget(self, action: #selector(previousPressed), for: .touchUpInside)
        addArrangedSubview(self.prevButton)

        self.nextButton = UIButton(type: .system)
        self.nextButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        self.nextButton.accessibilityLabel = "Next Result"
        self.nextButton.isAccessibilityElement = true
        self.nextButton.addTarget(self, action: #selector(nextPressed), for: .touchUpInside)
        addArrangedSubview(self.nextButton)
    }
}

extension ArticleSearchBar {
    @objc
    private func textDidChange(_: Notification) {
        self.delegate?.searchBar?(self, textDidChange: self.searchField.text ?? "")

        if self.searchField.text?.isEmpty ?? true {
            self.searchField.rightViewMode = .never
        } else {
            self.searchField.rightViewMode = .always
        }
    }

    @objc
    private func nextPressed() {
        self.delegate?.nextWasPressed?(self)
    }

    @objc
    private func previousPressed() {
        self.delegate?.previousWasPressed?(self)
    }

    @objc
    private func donePressed(_ _: Any? = nil) {
        self.delegate?.doneWasPressed?(self)
    }
}

extension ArticleSearchBar: UITextFieldDelegate {
    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.delegate?.nextWasPressed?(self)
        return false
    }

    func textFieldShouldBeginEditing(_: UITextField) -> Bool {
        self.shouldBeginEditing
    }
}
