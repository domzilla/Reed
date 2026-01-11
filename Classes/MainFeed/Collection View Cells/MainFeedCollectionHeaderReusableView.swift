//
//  MainFeedCollectionHeaderReusableView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor protocol MainFeedCollectionHeaderReusableViewDelegate: AnyObject {
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
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(headerTitle.text ?? "") \(unreadCount) \(unreadLabel) \(expandedStateMessage) "
			} else {
				return "\(headerTitle.text ?? "") \(expandedStateMessage) "
			}
		}
	}

	private var expandedStateMessage: String {
		set {}
		get {
			if disclosureExpanded {
				return NSLocalizedString("Expanded", comment: "Disclosure button expanded state for accessibility")
			}
			return NSLocalizedString("Collapsed", comment: "Disclosure button collapsed state for accessibility")
		}
	}


	private var _unreadCount: Int = 0

	var unreadCount: Int {
		get {
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			updateUnreadCount()
			unreadCountLabel.text = newValue.formatted()
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
		addSubview(headerTitle)
		addSubview(disclosureIndicator)
		addSubview(unreadCountLabel)

		unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
		unreadLabelWidthConstraint?.isActive = true

		NSLayoutConstraint.activate([
			headerTitle.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
			headerTitle.centerYAnchor.constraint(equalTo: centerYAnchor),
			headerTitle.trailingAnchor.constraint(lessThanOrEqualTo: unreadCountLabel.leadingAnchor, constant: -8),

			unreadCountLabel.trailingAnchor.constraint(equalTo: disclosureIndicator.leadingAnchor, constant: -8),
			unreadCountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

			disclosureIndicator.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
			disclosureIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
			disclosureIndicator.widthAnchor.constraint(equalToConstant: 16),
			disclosureIndicator.heightAnchor.constraint(equalToConstant: 16),
		])

		configureUI()
		addTapGesture()
	}

	func configureUI() {
		headerTitle.textColor = traitCollection.userInterfaceIdiom == .pad ? .tertiaryLabel : .label
	}

	private func addTapGesture() {
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(containerHeaderTapped))
		self.addGestureRecognizer(tapGesture)
		self.isUserInteractionEnabled = true
	}

	@objc private func containerHeaderTapped() {
		delegate?.mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(self)
	}

	func configureContainer(withTitle title: String) {
		headerTitle.text = title
		disclosureIndicator.transform = .identity
	}

	func updateExpandedState(animate: Bool) {

		if disclosureExpanded == false {
			unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
		} else {
			unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
			unreadLabelWidthConstraint?.isActive = false
		}

		let angle: CGFloat = disclosureExpanded ? 0 : -.pi / 2
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
		if !disclosureExpanded && unreadCount > 0 {
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
