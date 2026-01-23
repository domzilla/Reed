//
//  SettingsAccountTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class SettingsComboTableViewCell: VibrantTableViewCell {

	let comboImage: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	let comboNameLabel: UILabel = {
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
		accessoryType = .disclosureIndicator

		contentView.addSubview(comboImage)
		contentView.addSubview(comboNameLabel)

		NSLayoutConstraint.activate([
			comboImage.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			comboImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			comboImage.widthAnchor.constraint(equalToConstant: 24),
			comboImage.heightAnchor.constraint(equalToConstant: 24),

			comboNameLabel.leadingAnchor.constraint(equalTo: comboImage.trailingAnchor, constant: 12),
			comboNameLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			comboNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
		])
	}

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateLabelVibrancy(comboNameLabel, color: labelColor, animated: animated)

		let tintColor = isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
		if animated {
			UIView.animate(withDuration: Self.duration) {
				self.comboImage.tintColor = tintColor
			}
		} else {
			self.comboImage.tintColor = tintColor
		}
	}
}
