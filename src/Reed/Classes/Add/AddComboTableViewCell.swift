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
        self.setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    private func setupViews() {
        contentView.addSubview(self.iconImageView)
        contentView.addSubview(self.nameLabel)

        NSLayoutConstraint.activate([
            self.iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            self.iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.iconImageView.widthAnchor.constraint(equalToConstant: 24),
            self.iconImageView.heightAnchor.constraint(equalToConstant: 24),

            self.nameLabel.leadingAnchor.constraint(equalTo: self.iconImageView.trailingAnchor, constant: 12),
            self.nameLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            self.nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
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
        updateLabelVibrancy(self.nameLabel, color: labelColor, animated: animated)
    }
}
