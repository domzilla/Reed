//
//  SelectComboTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class SelectComboTableViewCell: VibrantTableViewCell {

	let icon: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	let label: UILabel = {
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
		contentView.addSubview(icon)
		contentView.addSubview(label)

		NSLayoutConstraint.activate([
			icon.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			icon.widthAnchor.constraint(equalToConstant: 24),
			icon.heightAnchor.constraint(equalToConstant: 24),

			label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
			label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
		])
	}

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)

		let iconTintColor = isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
		if animated {
			UIView.animate(withDuration: Self.duration) {
				self.icon.tintColor = iconTintColor
			}
		} else {
			self.icon.tintColor = iconTintColor
		}

		updateLabelVibrancy(label, color: labelColor, animated: animated)
	}

}
