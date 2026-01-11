//
//  AddFolderViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

final class AddFolderViewController: UITableViewController {

	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

	private var shouldDisplayPicker: Bool {
		return accounts.count > 1
	}

	private var accounts: [Account]! {
		didSet {
			if let predefinedAccount = accounts.first(where: { $0.accountID == AppDefaults.shared.addFolderAccountID }) {
				selectedAccount = predefinedAccount
			} else {
				selectedAccount = accounts[0]
			}
		}
	}

	private var selectedAccount: Account! {
		didSet {
			guard selectedAccount != oldValue else { return }
			accountLabel.text = selectedAccount.flatMap { ($0 as DisplayNameProvider).nameForDisplay }
		}
	}

	// MARK: - UI Elements

	private lazy var addButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: NSLocalizedString("Add", comment: "Add"), style: .prominent, target: self, action: #selector(add(_:)))
		button.isEnabled = false
		return button
	}()

	private lazy var nameTextField: UITextField = {
		let textField = UITextField()
		textField.placeholder = NSLocalizedString("Name", comment: "Name")
		textField.autocorrectionType = .no
		textField.autocapitalizationType = .words
		textField.returnKeyType = .done
		textField.clearButtonMode = .whileEditing
		textField.font = .preferredFont(forTextStyle: .body)
		textField.adjustsFontForContentSizeCategory = true
		textField.translatesAutoresizingMaskIntoConstraints = false
		return textField
	}()

	private lazy var accountLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var accountPickerView: UIPickerView = {
		let picker = UIPickerView()
		picker.translatesAutoresizingMaskIntoConstraints = false
		return picker
	}()

	// MARK: - Initialization

	init() {
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init()")
	}

	// MARK: - Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		title = NSLocalizedString("Add Folder", comment: "Add Folder")
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
		navigationItem.rightBarButtonItem = addButton

		accounts = AccountManager.shared
			.sortedActiveAccounts
			.filter { !$0.behaviors.contains(.disallowFolderManagement) }

		nameTextField.delegate = self

		if shouldDisplayPicker {
			accountPickerView.dataSource = self
			accountPickerView.delegate = self

			if let index = accounts.firstIndex(of: selectedAccount) {
				accountPickerView.selectRow(index, inComponent: 0, animated: false)
			}

		}

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LabelCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PickerCell")

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nameTextField)

		nameTextField.becomeFirstResponder()
    }

	// MARK: - Actions

	private func didSelect(_ account: Account) {
		AppDefaults.shared.addFolderAccountID = account.accountID
		selectedAccount = account
	}

	@objc func cancel(_ sender: Any) {
		dismiss(animated: true)
	}

	@objc func add(_ sender: Any) {
		guard let folderName = nameTextField.text else {
			return
		}

		Task { @MainActor in
			defer {
				dismiss(animated: true)
			}
			do {
				try await selectedAccount.addFolder(folderName)
			} catch {
				presentError(error)
			}
		}
	}

	@objc func textDidChange(_ note: Notification) {
		addButton.isEnabled = !(nameTextField.text?.isEmpty ?? false)
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return shouldDisplayPicker ? 2 : 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return 1
		case 1:
			return 2
		default:
			return 0
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch (indexPath.section, indexPath.row) {
		case (0, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none
			cell.contentView.addSubview(nameTextField)
			NSLayoutConstraint.activate([
				nameTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				nameTextField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				nameTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
				nameTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
			])
			return cell
		case (1, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none

			let titleLabel = UILabel()
			titleLabel.text = NSLocalizedString("Account", comment: "Account")
			titleLabel.font = .preferredFont(forTextStyle: .body)
			titleLabel.adjustsFontForContentSizeCategory = true
			titleLabel.translatesAutoresizingMaskIntoConstraints = false

			cell.contentView.addSubview(titleLabel)
			cell.contentView.addSubview(accountLabel)

			NSLayoutConstraint.activate([
				titleLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				titleLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
				accountLabel.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				accountLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
				titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accountLabel.leadingAnchor, constant: -8)
			])
			return cell
		case (1, 1):
			let cell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none
			cell.contentView.addSubview(accountPickerView)
			NSLayoutConstraint.activate([
				accountPickerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
				accountPickerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
				accountPickerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
				accountPickerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
			])
			return cell
		default:
			fatalError("Unexpected index path")
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return NSLocalizedString("Name", comment: "Name")
		case 1:
			return NSLocalizedString("Account", comment: "Account")
		default:
			return nil
		}
	}
}

extension AddFolderViewController: UIPickerViewDataSource, UIPickerViewDelegate {

	func numberOfComponents(in pickerView: UIPickerView) ->Int {
		return 1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return accounts.count
	}

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return (accounts[row] as DisplayNameProvider).nameForDisplay
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		didSelect(accounts[row])
	}

}

extension AddFolderViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
