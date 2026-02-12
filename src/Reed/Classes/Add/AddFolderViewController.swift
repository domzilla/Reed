//
//  AddFolderViewController.swift
//  Reed
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import RSCore
import UIKit

final class AddFolderViewController: UITableViewController {
    static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

    private var shouldDisplayPicker: Bool {
        self.dataStores.count > 1
    }

    private var dataStores: [DataStore]! {
        didSet {
            if
                let predefinedDataStore = dataStores
                    .first(where: { $0.dataStoreID == AppDefaults.shared.addFolderAccountID })
            {
                self.selectedDataStore = predefinedDataStore
            } else {
                self.selectedDataStore = self.dataStores[0]
            }
        }
    }

    private var selectedDataStore: DataStore! {
        didSet {
            guard self.selectedDataStore != oldValue else { return }
            self.accountLabel.text = self.selectedDataStore.flatMap { ($0 as DisplayNameProvider).nameForDisplay }
        }
    }

    // MARK: - UI Elements

    private lazy var addButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: NSLocalizedString("Add", comment: "Add"),
            style: .prominent,
            target: self,
            action: #selector(add(_:))
        )
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
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Add Folder", comment: "Add Folder")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(self.cancel(_:))
        )
        navigationItem.rightBarButtonItem = self.addButton

        self.dataStores = DataStore.shared.sortedActiveDataStores

        self.nameTextField.delegate = self

        if self.shouldDisplayPicker {
            self.accountPickerView.dataSource = self
            self.accountPickerView.delegate = self

            if let index = dataStores.firstIndex(of: selectedDataStore) {
                self.accountPickerView.selectRow(index, inComponent: 0, animated: false)
            }
        }

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LabelCell")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PickerCell")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self.nameTextField
        )

        self.nameTextField.becomeFirstResponder()
    }

    // MARK: - Actions

    private func didSelect(_ dataStore: DataStore) {
        AppDefaults.shared.addFolderAccountID = dataStore.dataStoreID
        self.selectedDataStore = dataStore
    }

    @objc
    func cancel(_: Any) {
        dismiss(animated: true)
    }

    @objc
    func add(_: Any) {
        guard let folderName = nameTextField.text else {
            return
        }

        Task { @MainActor in
            defer {
                dismiss(animated: true)
            }
            do {
                try await self.selectedDataStore.addFolder(folderName)
            } catch {
                presentError(error)
            }
        }
    }

    @objc
    func textDidChange(_: Notification) {
        self.addButton.isEnabled = !(self.nameTextField.text?.isEmpty ?? false)
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        self.shouldDisplayPicker ? 2 : 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            1
        case 1:
            2
        default:
            0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.selectionStyle = .none
            cell.contentView.addSubview(self.nameTextField)
            NSLayoutConstraint.activate([
                self.nameTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                self.nameTextField.trailingAnchor
                    .constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                self.nameTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
                self.nameTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11),
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
            cell.contentView.addSubview(self.accountLabel)

            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                self.accountLabel.trailingAnchor
                    .constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                self.accountLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.accountLabel.leadingAnchor, constant: -8),
            ])
            return cell
        case (1, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.selectionStyle = .none
            cell.contentView.addSubview(self.accountPickerView)
            NSLayoutConstraint.activate([
                self.accountPickerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                self.accountPickerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                self.accountPickerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                self.accountPickerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            ])
            return cell
        default:
            fatalError("Unexpected index path")
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            NSLocalizedString("Name", comment: "Name")
        case 1:
            NSLocalizedString("Account", comment: "Account")
        default:
            nil
        }
    }
}

extension AddFolderViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in _: UIPickerView) -> Int {
        1
    }

    func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        self.dataStores.count
    }

    func pickerView(_: UIPickerView, titleForRow row: Int, forComponent _: Int) -> String? {
        (self.dataStores[row] as DisplayNameProvider).nameForDisplay
    }

    func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        self.didSelect(self.dataStores[row])
    }
}

extension AddFolderViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
