//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

final class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	private enum AddAccountSections: Int, CaseIterable {
		case local = 0
		case icloud

		var sectionHeader: String {
			switch self {
			case .local:
				return NSLocalizedString("Local", comment: "Local Account")
			case .icloud:
				return NSLocalizedString("iCloud", comment: "iCloud Account")
			}
		}

		var sectionFooter: String {
			switch self {
			case .local:
				return NSLocalizedString("Local accounts do not sync your feeds across devices", comment: "Local Account")
			case .icloud:
				return NSLocalizedString("Your iCloud account syncs your feeds across your Mac and iOS devices", comment: "iCloud Account")
			}
		}

		var sectionContent: [AccountType] {
			switch self {
			case .local:
				return [.onMyMac]
			case .icloud:
				return [.cloudKit]
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return AddAccountSections.allCases.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == AddAccountSections.local.rawValue {
			return AddAccountSections.local.sectionContent.count
		}

		if section == AddAccountSections.icloud.rawValue {
			return AddAccountSections.icloud.sectionContent.count
		}

		return 0
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case AddAccountSections.local.rawValue:
			return AddAccountSections.local.sectionHeader
		case AddAccountSections.icloud.rawValue:
			return AddAccountSections.icloud.sectionHeader
		default:
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		switch section {
		case AddAccountSections.local.rawValue:
			return AddAccountSections.local.sectionFooter
		case AddAccountSections.icloud.rawValue:
			return AddAccountSections.icloud.sectionFooter
		default:
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsAccountTableViewCell", for: indexPath) as! SettingsComboTableViewCell

		switch indexPath.section {
		case AddAccountSections.local.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.local.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = Assets.accountImage(.onMyMac)
		case AddAccountSections.icloud.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.icloud.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = Assets.accountImage(AddAccountSections.icloud.sectionContent[indexPath.row])
			if AppDefaults.shared.isDeveloperBuild || AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit }) {
				cell.isUserInteractionEnabled = false
				cell.comboNameLabel?.isEnabled = false
			}
		default:
			return cell
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		switch indexPath.section {
		case AddAccountSections.local.rawValue:
			let type = AddAccountSections.local.sectionContent[indexPath.row]
			presentController(for: type)
		case AddAccountSections.icloud.rawValue:
			let type = AddAccountSections.icloud.sectionContent[indexPath.row]
			presentController(for: type)
		default:
			return
		}
	}

	private func presentController(for accountType: AccountType) {
		switch accountType {
		case .onMyMac:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "LocalAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! LocalAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .cloudKit:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "CloudKitAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! CloudKitAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		}
	}

	func dismiss() {
		navigationController?.popViewController(animated: false)
	}

}
