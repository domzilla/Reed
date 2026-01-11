//
//  MainFeedCollectionViewFolderCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor protocol MainFeedCollectionViewFolderCellDelegate: AnyObject {
	func mainFeedCollectionFolderViewCellDisclosureDidToggle(_ sender: MainFeedCollectionViewFolderCell, expanding: Bool)
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
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			if newValue == 0 {
				unreadCountLabel.isHidden = true
			} else {
				unreadCountLabel.isHidden = false
				updateUnreadCount()
			}
			unreadCountLabel.text = newValue.formatted()
		}
	}

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

	var disclosureExpanded = true {
		didSet {
			updateExpandedState(animate: true)
			updateUnreadCount()
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
		contentView.addSubview(folderTitle)
		contentView.addSubview(unreadCountLabel)
		contentView.addSubview(disclosureButton)

		disclosureButton.addTarget(self, action: #selector(toggleDisclosure), for: .touchUpInside)
		disclosureButton.addInteraction(UIPointerInteraction())

		NSLayoutConstraint.activate([
			faviconView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
			faviconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			faviconView.widthAnchor.constraint(equalToConstant: 24),
			faviconView.heightAnchor.constraint(equalToConstant: 24),

			folderTitle.leadingAnchor.constraint(equalTo: faviconView.trailingAnchor, constant: 8),
			folderTitle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			folderTitle.trailingAnchor.constraint(lessThanOrEqualTo: unreadCountLabel.leadingAnchor, constant: -8),

			unreadCountLabel.trailingAnchor.constraint(equalTo: disclosureButton.leadingAnchor, constant: -8),
			unreadCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

			disclosureButton.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
			disclosureButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			disclosureButton.widthAnchor.constraint(equalToConstant: 24),
			disclosureButton.heightAnchor.constraint(equalToConstant: 24),
		])
	}

	func updateExpandedState(animate: Bool) {
		let angle: CGFloat = disclosureExpanded ? 0 : -.pi / 2
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
		if !disclosureExpanded && unreadCount > 0 && unreadCountLabel.alpha != 1 {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountLabel.alpha = 1
			}
		} else {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountLabel.alpha = 0
			}
		}
	}

	@objc func toggleDisclosure() {
		setDisclosure(isExpanded: !disclosureExpanded, animated: true)
		delegate?.mainFeedCollectionFolderViewCellDisclosureDidToggle(self, expanding: disclosureExpanded)
	}

	func setDisclosure(isExpanded: Bool, animated: Bool) {
		disclosureExpanded = isExpanded
	}


	override var accessibilityLabel: String? {
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(String(describing: folderTitle.text)) \(unreadCount) \(unreadLabel)"
			} else {
				return (String(describing: folderTitle.text))
			}
		}
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)

		switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
		case (true, .pad):
			backgroundConfig.backgroundColor = .tertiarySystemFill
			folderTitle.textColor = Assets.Colors.primaryAccent
			folderTitle.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
			unreadCountLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
		case (true, .phone):
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			folderTitle.textColor = .white
			unreadCountLabel.textColor = .secondaryLabel
			faviconView.tintColor = .white
		default:
			folderTitle.textColor = .label
			faviconView.tintColor = Assets.Colors.primaryAccent
			folderTitle.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
		}

		if state.cellDropState == .targeted {
			backgroundConfig.backgroundColor = .tertiarySystemFill
		}

		self.backgroundConfiguration = backgroundConfig
	}

}
