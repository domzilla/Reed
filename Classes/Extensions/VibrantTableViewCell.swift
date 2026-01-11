//
//  VibrantTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Jim Correia on 9/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class VibrantTableViewCell: UITableViewCell {

	static let duration: TimeInterval = 0.6

	var labelColor: UIColor {
		return isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
	}

	var secondaryLabelColor: UIColor {
		return isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.secondaryLabel
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	private func commonInit() {
		applyThemeProperties()
	}

	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)
		updateVibrancy(animated: animated)
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		updateVibrancy(animated: animated)
	}

	/// Subclass overrides should call super
	func applyThemeProperties() {
		let selectedBackgroundView = UIView(frame: .zero)
		selectedBackgroundView.backgroundColor = Assets.Colors.secondaryAccent
		self.selectedBackgroundView = selectedBackgroundView
	}

	/// Subclass overrides should call super
	func updateVibrancy(animated: Bool) {
		updateLabelVibrancy(textLabel, color: labelColor, animated: animated)
		updateLabelVibrancy(detailTextLabel, color: labelColor, animated: animated)
	}

	func updateLabelVibrancy(_ label: UILabel?, color: UIColor, animated: Bool) {
		guard let label = label else { return }
		if animated {
			UIView.transition(with: label, duration: Self.duration, options: .transitionCrossDissolve, animations: {
				label.textColor = color
			}, completion: nil)
		} else {
			label.textColor = color
		}
	}

}

class VibrantBasicTableViewCell: VibrantTableViewCell {

	let iconImageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	let titleLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let detailLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.textAlignment = .right
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	var imageNormal: UIImage?
	var imageSelected: UIImage?

	var iconTint: UIColor {
		return isHighlighted || isSelected ? labelColor : Assets.Colors.primaryAccent
	}

	var iconImage: UIImage? {
		return isHighlighted || isSelected ? imageSelected : imageNormal
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}

	private func setupViews() {
		contentView.addSubview(iconImageView)
		contentView.addSubview(titleLabel)
		contentView.addSubview(detailLabel)

		NSLayoutConstraint.activate([
			iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 24),
			iconImageView.heightAnchor.constraint(equalToConstant: 24),

			titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
			titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

			detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
			detailLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
		])

		detailLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
	}

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateIconVibrancy(iconImageView, color: iconTint, image: iconImage, animated: animated)
		updateLabelVibrancy(titleLabel, color: labelColor, animated: animated)
		updateLabelVibrancy(detailLabel, color: secondaryLabelColor, animated: animated)
	}

	private func updateIconVibrancy(_ icon: UIImageView, color: UIColor, image: UIImage?, animated: Bool) {
		if animated {
			UIView.transition(with: icon, duration: Self.duration, options: .transitionCrossDissolve, animations: {
				icon.tintColor = color
				icon.image = image
			}, completion: nil)
		} else {
			icon.tintColor = color
			icon.image = image
		}
	}
}
