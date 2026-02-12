//
//  VibrantTableViewCell.swift
//  Reed
//
//  Created by Jim Correia on 9/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class VibrantTableViewCell: UITableViewCell {
    static let duration: TimeInterval = 0.6

    var labelColor: UIColor {
        isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
    }

    var secondaryLabelColor: UIColor {
        isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.secondaryLabel
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    private func commonInit() {
        self.applyThemeProperties()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        self.updateVibrancy(animated: animated)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.updateVibrancy(animated: animated)
    }

    /// Subclass overrides should call super
    func applyThemeProperties() {
        let selectedBackgroundView = UIView(frame: .zero)
        selectedBackgroundView.backgroundColor = Assets.Colors.secondaryAccent
        self.selectedBackgroundView = selectedBackgroundView
    }

    /// Subclass overrides should call super
    func updateVibrancy(animated: Bool) {
        self.updateLabelVibrancy(textLabel, color: self.labelColor, animated: animated)
        self.updateLabelVibrancy(detailTextLabel, color: self.labelColor, animated: animated)
    }

    func updateLabelVibrancy(_ label: UILabel?, color: UIColor, animated: Bool) {
        guard let label else { return }
        if animated {
            UIView.transition(with: label, duration: Self.duration, options: .transitionCrossDissolve, animations: {
                label.textColor = color
            }, completion: nil)
        } else {
            label.textColor = color
        }
    }
}
