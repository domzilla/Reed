//
//  MainFeedCollectionHeaderReusableView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor
protocol MainFeedCollectionHeaderReusableViewDelegate: AnyObject {
    func mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(_ view: MainFeedCollectionHeaderReusableView)
}

final class MainFeedCollectionHeaderReusableView: UICollectionReusableView {
    var delegate: MainFeedCollectionHeaderReusableViewDelegate?

    let headerTitle: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let disclosureIndicator: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let unreadCountLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var unreadLabelWidthConstraint: NSLayoutConstraint?

    override var accessibilityLabel: String? {
        set {}
        get {
            if self.unreadCount > 0 {
                let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
                return "\(self.headerTitle.text ?? "") \(self.unreadCount) \(unreadLabel) \(self.expandedStateMessage) "
            } else {
                return "\(self.headerTitle.text ?? "") \(self.expandedStateMessage) "
            }
        }
    }

    private var expandedStateMessage: String {
        set {}
        get {
            if self.disclosureExpanded {
                return NSLocalizedString("Expanded", comment: "Disclosure button expanded state for accessibility")
            }
            return NSLocalizedString("Collapsed", comment: "Disclosure button collapsed state for accessibility")
        }
    }

    private var _unreadCount: Int = 0

    var unreadCount: Int {
        get {
            self._unreadCount
        }
        set {
            self._unreadCount = newValue
            self.updateUnreadCount()
            self.unreadCountLabel.text = newValue.formatted()
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
        addSubview(self.headerTitle)
        addSubview(self.disclosureIndicator)
        addSubview(self.unreadCountLabel)

        self.unreadLabelWidthConstraint = self.unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
        self.unreadLabelWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            // Header title with top/bottom padding to drive header height (matching storyboard)
            self.headerTitle.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.headerTitle.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            self.headerTitle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            self.headerTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: self.unreadCountLabel.leadingAnchor,
                constant: -8
            ),

            self.unreadCountLabel.trailingAnchor.constraint(
                equalTo: self.disclosureIndicator.leadingAnchor,
                constant: -8
            ),
            self.unreadCountLabel.centerYAnchor.constraint(equalTo: self.headerTitle.centerYAnchor),

            self.disclosureIndicator.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            self.disclosureIndicator.centerYAnchor.constraint(equalTo: self.headerTitle.centerYAnchor),
            self.disclosureIndicator.widthAnchor.constraint(equalToConstant: 16),
            self.disclosureIndicator.heightAnchor.constraint(equalToConstant: 16),
        ])

        self.configureUI()
        self.addTapGesture()
    }

    func configureUI() {
        self.headerTitle.textColor = traitCollection.userInterfaceIdiom == .pad ? .tertiaryLabel : .label
    }

    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(containerHeaderTapped))
        self.addGestureRecognizer(tapGesture)
        self.isUserInteractionEnabled = true
    }

    @objc
    private func containerHeaderTapped() {
        self.delegate?.mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(self)
    }

    func configureContainer(withTitle title: String) {
        self.headerTitle.text = title
        self.disclosureIndicator.transform = .identity
    }

    func updateExpandedState(animate: Bool) {
        if self.disclosureExpanded == false {
            self.unreadLabelWidthConstraint = self.unreadCountLabel.widthAnchor
                .constraint(lessThanOrEqualToConstant: 80)
        } else {
            self.unreadLabelWidthConstraint = self.unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
            self.unreadLabelWidthConstraint?.isActive = false
        }

        let angle: CGFloat = self.disclosureExpanded ? 0 : -.pi / 2
        let transform = CGAffineTransform(rotationAngle: angle)
        let animations = {
            self.disclosureIndicator.transform = transform
        }
        if animate {
            UIView.animate(withDuration: 0.3, animations: animations)
        } else {
            animations()
        }
    }

    func updateUnreadCount() {
        if !self.disclosureExpanded, self.unreadCount > 0 {
            UIView.animate(withDuration: 0.3) {
                self.unreadCountLabel.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.unreadCountLabel.alpha = 0
            }
        }
    }
}
