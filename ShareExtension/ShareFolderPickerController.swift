//
//  ShareFolderPickerController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor protocol ShareFolderPickerControllerDelegate: AnyObject {
	func shareFolderPickerDidSelect(_ container: ExtensionContainer)
}

final class ShareFolderPickerController: UITableViewController {

	var containers: [ExtensionContainer]?
	var selectedContainerID: ContainerIdentifier?

	weak var delegate: ShareFolderPickerControllerDelegate?

	override func viewDidLoad() {
		tableView.register(ShareFolderPickerCell.self, forCellReuseIdentifier: "AccountCell")
		tableView.register(ShareFolderPickerCell.self, forCellReuseIdentifier: "FolderCell")

	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return containers?.count ?? 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let container = containers?[indexPath.row]
		let cell: ShareFolderPickerCell = {
			if container is ExtensionAccount {
				return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! ShareFolderPickerCell
			} else {
				return tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! ShareFolderPickerCell
			}
		}()

		if let account = container as? ExtensionAccount {
			cell.iconImageView.image = ShareAssets.accountImage(account.type)
		} else {
			cell.iconImageView.image = ShareAssets.Images.mainFolder.image
		}

		cell.nameLabel.text = container?.name ?? ""

		if let containerID = container?.containerID, containerID == selectedContainerID {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}

        return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let container = containers?[indexPath.row] else { return }

		if let account = container as? ExtensionAccount, account.disallowFeedInRootFolder {
			tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
		} else {
			let cell = tableView.cellForRow(at: indexPath)
			cell?.accessoryType = .checkmark
			delegate?.shareFolderPickerDidSelect(container)
		}
	}

}
