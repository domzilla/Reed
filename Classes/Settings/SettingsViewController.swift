//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import CoreServices
import SwiftUI
import UniformTypeIdentifiers
import RSCore

final class SettingsViewController: UITableViewController {

	var scrollToArticlesSection = false

	// MARK: - UI Elements

	private lazy var timelineSortOrderSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchTimelineOrder(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var groupByFeedSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchGroupByFeed(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var refreshClearsReadArticlesSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchClearsReadArticles(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var confirmMarkAllAsReadSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchConfirmMarkAllAsRead(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var showFullscreenArticlesSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchFullscreenArticles(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var openLinksInNetNewsWireSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchBrowserPreference(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var enableJavaScriptSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(switchJavaScriptPreference(_:)), for: .valueChanged)
		return toggle
	}()

	// Section titles
	private let sectionTitles = [
		NSLocalizedString("Notifications, Badge, Data, & More", comment: "Notifications, Badge, Data, & More"),
		NSLocalizedString("Display Options", comment: "Display Options"),
		NSLocalizedString("Feeds", comment: "Feeds"),
		NSLocalizedString("Timeline", comment: "Timeline"),
		NSLocalizedString("Articles", comment: "Articles")
	]

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

		title = NSLocalizedString("Settings", comment: "Settings")
		// Use X button to match storyboard
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(done(_:)))

		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SwitchCell")
		// Register DetailCell with value1 style for showing detail text on right
		tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "DetailCell")

		tableView.rowHeight = UITableView.automaticDimension
		tableView.estimatedRowHeight = 44
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		timelineSortOrderSwitch.isOn = AppDefaults.shared.timelineSortDirection == .orderedAscending
		groupByFeedSwitch.isOn = AppDefaults.shared.timelineGroupByFeed
		refreshClearsReadArticlesSwitch.isOn = AppDefaults.shared.refreshClearsReadArticles
		confirmMarkAllAsReadSwitch.isOn = AppDefaults.shared.confirmMarkAllAsRead
		showFullscreenArticlesSwitch.isOn = AppDefaults.shared.articleFullscreenAvailable
		enableJavaScriptSwitch.isOn = AppDefaults.shared.isArticleContentJavascriptEnabled
		openLinksInNetNewsWireSwitch.isOn = !AppDefaults.shared.useSystemBrowser

		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false

		let wrapperView = UIView(frame: CGRect(x: 0, y: 0, width: buildLabel.frame.width, height: buildLabel.frame.height + 10.0))
		wrapperView.translatesAutoresizingMaskIntoConstraints = false
		wrapperView.addSubview(buildLabel)
		tableView.tableFooterView = wrapperView

		tableView.reloadData()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		if scrollToArticlesSection {
			tableView.scrollToRow(at: IndexPath(row: 0, section: 4), at: .top, animated: true)
			scrollToArticlesSection = false
		}
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 5
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0: return 1 // System Settings
		case 1: return 1 // Display Options (Appearance)
		case 2: return 2 // Feeds (Import/Export)
		case 3: return 4 // Timeline
		case 4: // Articles
			return traitCollection.userInterfaceIdiom == .phone ? 4 : 3
		default: return 0
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sectionTitles[section].isEmpty ? nil : sectionTitles[section]
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch (indexPath.section, indexPath.row) {
		// Section 0: System Settings
		case (0, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Open System Settings", comment: "Open System Settings")
			cell.accessoryType = .disclosureIndicator
			return cell

		// Section 1: Display Options
		case (1, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Appearance", comment: "Appearance")
			cell.detailTextLabel?.text = String(describing: AppDefaults.userInterfaceColorPalette)
			cell.accessoryType = .disclosureIndicator
			return cell

		// Section 2: Feeds
		case (2, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Import Subscriptions...", comment: "Import Subscriptions")
			cell.accessoryType = .none
			return cell
		case (2, 1):
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Export Subscriptions...", comment: "Export Subscriptions")
			cell.accessoryType = .none
			return cell

		// Section 3: Timeline
		case (3, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Sort Oldest to Newest", comment: "Sort Oldest to Newest")
			cell.accessoryView = timelineSortOrderSwitch
			cell.selectionStyle = .none
			return cell
		case (3, 1):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Group by Feed", comment: "Group by Feed")
			cell.accessoryView = groupByFeedSwitch
			cell.selectionStyle = .none
			return cell
		case (3, 2):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Refresh to Clear Read Articles", comment: "Refresh to Clear Read Articles")
			cell.accessoryView = refreshClearsReadArticlesSwitch
			cell.selectionStyle = .none
			return cell
		case (3, 3):
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Timeline Layout", comment: "Timeline Layout")
			cell.accessoryType = .disclosureIndicator
			return cell

		// Section 4: Articles
		case (4, 0):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Confirm Mark All as Read", comment: "Confirm Mark All as Read")
			cell.accessoryView = confirmMarkAllAsReadSwitch
			cell.selectionStyle = .none
			return cell
		case (4, 1):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Enable Full Screen Articles", comment: "Enable Full Screen Articles")
			cell.accessoryView = showFullscreenArticlesSwitch
			cell.selectionStyle = .none
			return cell
		case (4, 2):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Open Links in App", comment: "Open Links in App")
			cell.accessoryView = openLinksInNetNewsWireSwitch
			cell.selectionStyle = .none
			return cell
		case (4, 3):
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Enable JavaScript", comment: "Enable JavaScript")
			cell.accessoryView = enableJavaScriptSwitch
			cell.selectionStyle = .none
			return cell

		default:
			return UITableViewCell()
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch (indexPath.section, indexPath.row) {
		case (0, 0):
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		case (1, 0):
			let appearance = ColorPaletteTableViewController()
			navigationController?.pushViewController(appearance, animated: true)

		case (2, 0):
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			if let sourceView = tableView.cellForRow(at: indexPath) {
				let sourceRect = tableView.rectForRow(at: indexPath)
				importOPML(sourceView: sourceView, sourceRect: sourceRect)
			}
		case (2, 1):
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			if let sourceView = tableView.cellForRow(at: indexPath) {
				let sourceRect = tableView.rectForRow(at: indexPath)
				exportOPML(sourceView: sourceView, sourceRect: sourceRect)
			}

		case (3, 3):
			let timeline = ModernTimelineCustomizerTableViewController()
			navigationController?.pushViewController(timeline, animated: true)

		default:
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}

	// MARK: - Actions

	@objc func done(_ sender: Any) {
		dismiss(animated: true)
	}

	@objc func switchTimelineOrder(_ sender: Any) {
		AppDefaults.shared.timelineSortDirection = timelineSortOrderSwitch.isOn ? .orderedAscending : .orderedDescending
	}

	@objc func switchGroupByFeed(_ sender: Any) {
		AppDefaults.shared.timelineGroupByFeed = groupByFeedSwitch.isOn
	}

	@objc func switchClearsReadArticles(_ sender: Any) {
		AppDefaults.shared.refreshClearsReadArticles = refreshClearsReadArticlesSwitch.isOn
	}

	@objc func switchConfirmMarkAllAsRead(_ sender: Any) {
		AppDefaults.shared.confirmMarkAllAsRead = confirmMarkAllAsReadSwitch.isOn
	}

	@objc func switchFullscreenArticles(_ sender: Any) {
		AppDefaults.shared.articleFullscreenAvailable = showFullscreenArticlesSwitch.isOn
	}

	@objc func switchBrowserPreference(_ sender: Any) {
		AppDefaults.shared.useSystemBrowser = !openLinksInNetNewsWireSwitch.isOn
	}

	@objc func switchJavaScriptPreference(_ sender: Any) {
		AppDefaults.shared.isArticleContentJavascriptEnabled = enableJavaScriptSwitch.isOn
 	}

	// MARK: - Notifications

	@objc func contentSizeCategoryDidChange() {
		tableView.reloadData()
	}

}

// MARK: OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		let account = AccountManager.shared.defaultAccount
		for url in urls {
			account.importOPML(url) { result in
				switch result {
				case .success:
					break
				case .failure:
					let title = NSLocalizedString("Import Failed", comment: "Import Failed")
					let message = NSLocalizedString("We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.", comment: "Import Failed Message")
					self.presentError(title: title, message: message)
				}
			}
		}
	}

}

// MARK: Private

private extension SettingsViewController {

	func importOPML(sourceView: UIView, sourceRect: CGRect) {
		// Single account - import directly
		importOPMLDocumentPicker()
	}

	func importOPMLDocumentPicker() {
		var contentTypes: [UTType] = []

		// Create UTType for .opml files by extension, without requiring conformance.
		// This ensures files ending in .opml can be selected no matter how OPML is registered.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4858>
		if let opmlByExtension = UTType(filenameExtension: "opml") {
			contentTypes.append(opmlByExtension)
		}

		// Also try the registered org.opml.opml UTI if it exists
		if let registeredOPML = UTType("org.opml.opml") {
			contentTypes.append(registeredOPML)
		}

		// Include XML as a fallback
		contentTypes.append(.xml)

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
		documentPicker.delegate = self
		documentPicker.modalPresentationStyle = .formSheet
		self.present(documentPicker, animated: true)
	}

	func exportOPML(sourceView: UIView, sourceRect: CGRect) {
		// Single account - export directly
		exportOPMLDocumentPicker()
	}

	func exportOPMLDocumentPicker() {
		let account = AccountManager.shared.defaultAccount

		let filename = "Subscriptions.opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		do {
			try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		} catch {
			self.presentError(title: "OPML Export Error", message: error.localizedDescription)
		}

		let docPicker = UIDocumentPickerViewController(forExporting: [tempFile])
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
	}
}

// MARK: - Value1 Style Cell

private final class Value1TableViewCell: UITableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .value1, reuseIdentifier: reuseIdentifier)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init(style:reuseIdentifier:)")
	}
}
