//
//  AddFeedFolderViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

@MainActor protocol AddFeedFolderViewControllerDelegate {
	func didSelect(container: Container)
}

final class AddFeedFolderViewController: UITableViewController {

	var delegate: AddFeedFolderViewControllerDelegate?
	var initialContainer: Container?

	var containers = [Container]()

	// MARK: - Initialization

	init() {
		// Use .grouped to match storyboard (plain list style, not insetGrouped card style)
		super.init(style: .grouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init()")
	}

	// MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

		title = NSLocalizedString("Select Folder", comment: "Select Folder")
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))

		tableView.register(AddComboTableViewCell.self, forCellReuseIdentifier: "AccountCell")
		tableView.register(AddComboTableViewCell.self, forCellReuseIdentifier: "FolderCell")

		let sortedActiveAccounts = AccountManager.shared.sortedActiveAccounts

		for account in sortedActiveAccounts {
			containers.append(account)
			if let sortedFolders = account.sortedFolders {
				containers.append(contentsOf: sortedFolders)
			}
		}
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return containers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let container = containers[indexPath.row]
		let cell: AddComboTableViewCell = {
			if container is Account {
				return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AddComboTableViewCell
			} else {
				return tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! AddComboTableViewCell
			}
		}()

		if let smallIconProvider = container as? SmallIconProvider {
			cell.iconImageView.image = smallIconProvider.smallIcon?.image
		}

		if let displayNameProvider = container as? DisplayNameProvider {
			cell.nameLabel.text = displayNameProvider.nameForDisplay
		}

		if let compContainer = initialContainer, container === compContainer {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}

        return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let container = containers[indexPath.row]

		if let account = container as? Account, account.behaviors.contains(.disallowFeedInRootFolder) {
			tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
		} else {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.accessoryType = .checkmark
			delegate?.didSelect(container: container)
			dismissViewController()
		}
	}

	// MARK: Actions

	@objc func cancel(_ sender: Any) {
		dismissViewController()
	}
}

private extension AddFeedFolderViewController {

	func dismissViewController() {
		dismiss(animated: true)
	}
}
