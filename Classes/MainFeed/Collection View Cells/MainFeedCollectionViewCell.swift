//
//  MainFeedCollectionViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import RSTree


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
			faviconView.iconImage = iconImage
			if let preferredColor = iconImage?.preferredColor {
				faviconView.tintColor = UIColor(cgColor: preferredColor)
			} else {
				faviconView.tintColor = Assets.Colors.secondaryAccent
			}
		}
	}

	private var _unreadCount: Int = 0

	var unreadCount: Int {
		get {
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			if newValue == 0 {
				unreadCountLabel.isHidden = true
			} else {
				unreadCountLabel.isHidden = false
			}
			unreadCountLabel.text = newValue.formatted()
		}
	}

	/// If the feed is contained in a folder, the indentation level is 1
	/// and the cell's favicon leading constrain is increased. Otherwise,
	/// it has the standard leading constraint.
	var indentationLevel: Int = 0 {
		didSet {
			if indentationLevel == 1 {
				faviconLeadingConstraint?.constant = 32
			} else {
				faviconLeadingConstraint?.constant = 16
			}
		}
	}

	override var accessibilityLabel: String? {
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(String(describing: feedTitle.text)) \(unreadCount) \(unreadLabel)"
			} else {
				return (String(describing: feedTitle.text))
			}
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init(frame:)")
	}

	private func setupViews() {
		contentView.addSubview(faviconView)
		contentView.addSubview(feedTitle)
		contentView.addSubview(unreadCountLabel)

		faviconLeadingConstraint = faviconView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 16)

		NSLayoutConstraint.activate([
			faviconLeadingConstraint!,
			faviconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
			faviconView.widthAnchor.constraint(equalToConstant: 24),
			faviconView.heightAnchor.constraint(equalToConstant: 24),

			feedTitle.leadingAnchor.constraint(equalTo: faviconView.trailingAnchor, constant: 8),
			feedTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
			feedTitle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
			feedTitle.trailingAnchor.constraint(lessThanOrEqualTo: unreadCountLabel.leadingAnchor, constant: -8),

			unreadCountLabel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
			unreadCountLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
		])
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)

		switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
		case (true, .pad):
			backgroundConfig.backgroundColor = .tertiarySystemFill
			feedTitle.textColor = Assets.Colors.primaryAccent
			feedTitle.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
											   weight: .semibold)
			unreadCountLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
		case (true, .phone):
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			feedTitle.textColor = .white
			unreadCountLabel.textColor = .secondaryLabel
			if feedTitle.text == "All Unread" {
				faviconView.tintColor = .white
			}
		default:
			feedTitle.textColor = .label
			feedTitle.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.textColor = .secondaryLabel
			if traitCollection.userInterfaceIdiom == .phone {
				if feedTitle.text == "All Unread" {
					if let preferredColor = iconImage?.preferredColor {
						faviconView.tintColor = UIColor(cgColor: preferredColor)
					} else {
						faviconView.tintColor = Assets.Colors.secondaryAccent
					}
				}
			}
		}
		self.backgroundConfiguration = backgroundConfig
	}

}

