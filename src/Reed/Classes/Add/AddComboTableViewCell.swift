//
//  AddComboTableViewCell.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class AddComboTableViewCell: VibrantTableViewCell {

	let iconImageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	let nameLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init(style:reuseIdentifier:)")
	}

	private func setupViews() {
		contentView.addSubview(iconImageView)
		contentView.addSubview(nameLabel)

		NSLayoutConstraint.activate([
			iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 24),
			iconImageView.heightAnchor.constraint(equalToConstant: 24),

			nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
			nameLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
		])
	}

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)

		let iconTintColor = isHighlighted || isSelected ? Assets.Colors.vibrantText : Assets.Colors.secondaryAccent
		if animated {
			UIView.animate(withDuration: Self.duration) {
				self.iconImageView.tintColor = iconTintColor
			}
		} else {
			self.iconImageView.tintColor = iconTintColor
		}
		updateLabelVibrancy(nameLabel, color: labelColor, animated: animated)
	}
}
