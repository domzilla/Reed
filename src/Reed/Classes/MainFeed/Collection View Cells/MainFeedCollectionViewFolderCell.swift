//
//  MainFeedCollectionViewFolderCell.swift
//  Reed
//
//  Created by Stuart Breckenridge on 14/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor
protocol MainFeedCollectionViewFolderCellDelegate: AnyObject {
    func mainFeedCollectionFolderViewCellDisclosureDidToggle(
        _ sender: MainFeedCollectionViewFolderCell,
        expanding: Bool
    )
}

class MainFeedCollectionViewFolderCell: UICollectionViewCell {
    let folderTitle: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
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

    let disclosureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var delegate: MainFeedCollectionViewFolderCellDelegate?

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
                self.updateUnreadCount()
            }
            self.unreadCountLabel.text = newValue.formatted()
        }
    }

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

    var disclosureExpanded = true {
        didSet {
            self.updateExpandedState(animate: true)
            self.updateUnreadCount()
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
        contentView.addSubview(self.folderTitle)
        contentView.addSubview(self.unreadCountLabel)
        contentView.addSubview(self.disclosureButton)

        self.disclosureButton.addTarget(self, action: #selector(self.toggleDisclosure), for: .touchUpInside)
        self.disclosureButton.addInteraction(UIPointerInteraction())

        NSLayoutConstraint.activate([
            self.faviconView.leadingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            self.faviconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.faviconView.widthAnchor.constraint(equalToConstant: 24),
            self.faviconView.heightAnchor.constraint(equalToConstant: 24),

            // Folder title with top/bottom padding to drive cell height (matching storyboard)
            self.folderTitle.leadingAnchor.constraint(equalTo: self.faviconView.trailingAnchor, constant: 8),
            self.folderTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            self.folderTitle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            self.folderTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: self.unreadCountLabel.leadingAnchor,
                constant: -8
            ),

            self.unreadCountLabel.trailingAnchor.constraint(equalTo: self.disclosureButton.leadingAnchor, constant: -8),
            self.unreadCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            self.disclosureButton.trailingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            self.disclosureButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.disclosureButton.widthAnchor.constraint(equalToConstant: 24),
            self.disclosureButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    func updateExpandedState(animate: Bool) {
        let angle: CGFloat = self.disclosureExpanded ? 0 : -.pi / 2
        let transform = CGAffineTransform(rotationAngle: angle)
        let animations = {
            self.disclosureButton.transform = transform
        }
        if animate {
            UIView.animate(withDuration: 0.3, animations: animations)
        } else {
            animations()
        }
    }

    func updateUnreadCount() {
        if !self.disclosureExpanded, self.unreadCount > 0, self.unreadCountLabel.alpha != 1 {
            UIView.animate(withDuration: 0.3) {
                self.unreadCountLabel.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.unreadCountLabel.alpha = 0
            }
        }
    }

    @objc
    func toggleDisclosure() {
        self.setDisclosure(isExpanded: !self.disclosureExpanded, animated: true)
        self.delegate?.mainFeedCollectionFolderViewCellDisclosureDidToggle(self, expanding: self.disclosureExpanded)
    }

    func setDisclosure(isExpanded: Bool, animated _: Bool) {
        self.disclosureExpanded = isExpanded
    }

    override var accessibilityLabel: String? {
        set {}
        get {
            if self.unreadCount > 0 {
                let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
                return "\(String(describing: self.folderTitle.text)) \(self.unreadCount) \(unreadLabel)"
            } else {
                return String(describing: self.folderTitle.text)
            }
        }
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)

        switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
        case (true, .pad):
            backgroundConfig.backgroundColor = .tertiarySystemFill
            self.folderTitle.textColor = Assets.Colors.primaryAccent
            self.folderTitle.font = UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .semibold
            )
            self.unreadCountLabel.font = UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .semibold
            )
        case (true, .phone):
            backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
            self.folderTitle.textColor = .white
            self.unreadCountLabel.textColor = .secondaryLabel
            self.faviconView.tintColor = .white
        default:
            self.folderTitle.textColor = .label
            self.faviconView.tintColor = Assets.Colors.primaryAccent
            self.folderTitle.font = UIFont.preferredFont(forTextStyle: .body)
            self.unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
        }

        if state.cellDropState == .targeted {
            backgroundConfig.backgroundColor = .tertiarySystemFill
        }

        self.backgroundConfiguration = backgroundConfig
    }
}
