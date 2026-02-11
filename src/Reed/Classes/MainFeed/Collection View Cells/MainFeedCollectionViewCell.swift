//
//  MainFeedCollectionViewCell.swift
//  Reed
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import RSCore
import RSTree
import UIKit

class MainFeedCollectionViewCell: UICollectionViewCell {
    let feedTitle: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let faviconView: IconView = {
        let view = IconView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let unreadCountLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var faviconLeadingConstraint: NSLayoutConstraint?

    var iconImage: IconImage? {
        didSet {
            self.faviconView.iconImage = self.iconImage
            if let preferredColor = iconImage?.preferredColor {
                self.faviconView.tintColor = UIColor(cgColor: preferredColor)
            } else {
                self.faviconView.tintColor = Assets.Colors.secondaryAccent
            }
        }
    }

    private var _unreadCount: Int = 0

    var unreadCount: Int {
        get {
            self._unreadCount
        }
        set {
            self._unreadCount = newValue
            if newValue == 0 {
                self.unreadCountLabel.isHidden = true
            } else {
                self.unreadCountLabel.isHidden = false
            }
            self.unreadCountLabel.text = newValue.formatted()
        }
    }

    /// If the feed is contained in a folder, the indentation level is 1
    /// and the cell's favicon leading constrain is increased. Otherwise,
    /// it has the standard leading constraint.
    var indentationLevel: Int = 0 {
        didSet {
            if self.indentationLevel == 1 {
                self.faviconLeadingConstraint?.constant = 32
            } else {
                self.faviconLeadingConstraint?.constant = 16
            }
        }
    }

    override var accessibilityLabel: String? {
        set {}
        get {
            if self.unreadCount > 0 {
                let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
                return "\(String(describing: self.feedTitle.text)) \(self.unreadCount) \(unreadLabel)"
            } else {
                return String(describing: self.feedTitle.text)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(frame:)")
    }

    private func setupViews() {
        contentView.addSubview(self.faviconView)
        contentView.addSubview(self.feedTitle)
        contentView.addSubview(self.unreadCountLabel)

        self.faviconLeadingConstraint = self.faviconView.leadingAnchor.constraint(
            equalTo: contentView.safeAreaLayoutGuide.leadingAnchor,
            constant: 16
        )

        NSLayoutConstraint.activate([
            self.faviconLeadingConstraint!,
            // Icon vertically centered in cell (matching storyboard)
            self.faviconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.faviconView.widthAnchor.constraint(equalToConstant: 24),
            self.faviconView.heightAnchor.constraint(equalToConstant: 24),

            // Text with padding to drive cell height (14pt matches storyboard)
            self.feedTitle.leadingAnchor.constraint(equalTo: self.faviconView.trailingAnchor, constant: 8),
            self.feedTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            self.feedTitle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            self.feedTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: self.unreadCountLabel.leadingAnchor,
                constant: -8
            ),

            // Unread count vertically centered (matching storyboard)
            self.unreadCountLabel.trailingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            self.unreadCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)

        switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
        case (true, .pad):
            backgroundConfig.backgroundColor = .tertiarySystemFill
            self.feedTitle.textColor = Assets.Colors.primaryAccent
            self.feedTitle.font = UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .semibold
            )
            self.unreadCountLabel.font = UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .semibold
            )
        case (true, .phone):
            backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
            self.feedTitle.textColor = .white
            self.unreadCountLabel.textColor = .secondaryLabel
            if self.feedTitle.text == "All Unread" {
                self.faviconView.tintColor = .white
            }
        default:
            self.feedTitle.textColor = .label
            self.feedTitle.font = UIFont.preferredFont(forTextStyle: .body)
            self.unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
            self.unreadCountLabel.textColor = .secondaryLabel
            if traitCollection.userInterfaceIdiom == .phone {
                if self.feedTitle.text == "All Unread" {
                    if let preferredColor = iconImage?.preferredColor {
                        self.faviconView.tintColor = UIColor(cgColor: preferredColor)
                    } else {
                        self.faviconView.tintColor = Assets.Colors.secondaryAccent
                    }
                }
            }
        }
        self.backgroundConfiguration = backgroundConfig
    }
}
