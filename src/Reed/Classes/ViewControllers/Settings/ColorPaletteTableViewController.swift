//
//  ColorPaletteTableViewController.swift
//  Reed
//
//  Created by Maurice Parker on 3/15/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class ColorPaletteTableViewController: UITableViewController {
    // MARK: - Initialization

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Appearance", comment: "Appearance")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        UserInterfaceColorPalette.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let rowColorPalette = UserInterfaceColorPalette.allCases[indexPath.row]
        cell.textLabel?.text = String(describing: rowColorPalette)
        if rowColorPalette == AppDefaults.userInterfaceColorPalette {
            cell.accessoryType = .checkmark
            cell.accessibilityValue = NSLocalizedString(
                "Selected",
                tableName: "Accessibility",
                comment: "Accessibility value announcing that this appearance row is the selected one"
            )
        } else {
            cell.accessoryType = .none
            cell.accessibilityValue = nil
        }
        cell.accessibilityIdentifier = "ColorPaletteTableViewController.paletteCell"
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let colorPalette = UserInterfaceColorPalette(rawValue: indexPath.row) {
            AppDefaults.userInterfaceColorPalette = colorPalette
        }
        navigationController?.popViewController(animated: true)
    }
}
