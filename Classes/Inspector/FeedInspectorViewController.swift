//
//  FeedInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import UserNotifications
import RSCore

final class FeedInspectorViewController: UITableViewController {

	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 500.0)

	var feed: Feed!
	var container: Container?

	private var headerView: InspectorIconHeaderView?
	private var iconImage: IconImage? {
		return IconImageCache.shared.imageForFeed(feed)
	}

	private var shouldHideHomePageSection: Bool {
		return feed.homePageURL == nil
	}

	private var authorizationStatus: UNAuthorizationStatus?

	// MARK: - UI Elements

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
		textField.delegate = self
		return textField
	}()

	private lazy var notifyAboutNewArticlesSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(notifyAboutNewArticlesChanged(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var alwaysShowReaderViewSwitch: UISwitch = {
		let toggle = UISwitch()
		toggle.addTarget(self, action: #selector(alwaysShowReaderViewChanged(_:)), for: .valueChanged)
		return toggle
	}()

	private lazy var homePageLabel: InteractiveLabel = {
		let label = InteractiveLabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var feedURLLabel: InteractiveLabel = {
		let label = InteractiveLabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
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

		// Checkmark on left to match storyboard
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))

		tableView.register(InspectorIconHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SwitchCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LabelCell")
		tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "FolderCell")

		navigationItem.title = feed.nameForDisplay
		nameTextField.text = feed.nameForDisplay

		notifyAboutNewArticlesSwitch.setOn(feed.isNotifyAboutNewArticles ?? false, animated: false)

		alwaysShowReaderViewSwitch.setOn(feed.isArticleExtractorAlwaysOn ?? false, animated: false)

		homePageLabel.text = feed.homePageURL
		feedURLLabel.text = feed.url

		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(updateNotificationSettings), name: UIApplication.willEnterForegroundNotification, object: nil)

	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateNotificationSettings()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if nameTextField.text != feed.nameForDisplay {
			let nameText = nameTextField.text ?? ""
			let newName = nameText.isEmpty ? (feed.name ?? NSLocalizedString("Untitled", comment: "Feed name")) : nameText
			feed.rename(to: newName) { _ in }
		}
	}

	// MARK: - Actions

	@objc func feedIconDidBecomeAvailable(_ notification: Notification) {
		headerView?.iconView.iconImage = iconImage
	}

	@objc func notifyAboutNewArticlesChanged(_ sender: Any) {
		guard let authorizationStatus else {
			notifyAboutNewArticlesSwitch.isOn = !notifyAboutNewArticlesSwitch.isOn
			return
		}
		if authorizationStatus == .denied {
			notifyAboutNewArticlesSwitch.isOn = !notifyAboutNewArticlesSwitch.isOn
			present(notificationUpdateErrorAlert(), animated: true, completion: nil)
		} else if authorizationStatus == .authorized {
			feed.isNotifyAboutNewArticles = notifyAboutNewArticlesSwitch.isOn
		} else {
			UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .sound, .alert]) { (granted, error) in
				Task { @MainActor in
					self.updateNotificationSettings()
					if granted {
						self.feed.isNotifyAboutNewArticles = self.notifyAboutNewArticlesSwitch.isOn
						UIApplication.shared.registerForRemoteNotifications()
					} else {
						self.notifyAboutNewArticlesSwitch.isOn = !self.notifyAboutNewArticlesSwitch.isOn
					}
				}
			}
		}
	}

	@objc func alwaysShowReaderViewChanged(_ sender: Any) {
		feed.isArticleExtractorAlwaysOn = alwaysShowReaderViewSwitch.isOn
	}

	@objc func done(_ sender: Any) {
		dismiss(animated: true)
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return shouldHideHomePageSection ? 2 : 3
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let actualSection = actualSectionIndex(for: section)
		switch actualSection {
		case 0:
			return 4 // Name, Notify, Reader View, Folder
		case 1:
			return 1 // Home Page
		case 2:
			return 1 // Feed URL
		default:
			return 0
		}
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : UITableView.automaticDimension
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let actualSection = actualSectionIndex(for: indexPath.section)

		switch (actualSection, indexPath.row) {
		case (0, 0):
			// Name text field
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

		case (0, 1):
			// Notify about new articles switch
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Notify About New Articles", comment: "Notify About New Articles")
			cell.textLabel?.font = .preferredFont(forTextStyle: .body)
			cell.textLabel?.adjustsFontForContentSizeCategory = true
			cell.textLabel?.numberOfLines = 2
			cell.detailTextLabel?.text = feed.notificationDisplayName.capitalized
			cell.accessoryView = notifyAboutNewArticlesSwitch
			cell.selectionStyle = .none
			return cell

		case (0, 2):
			// Always show reader view switch (matching storyboard label)
			let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Always Use Reader View", comment: "Always Use Reader View")
			cell.textLabel?.font = .preferredFont(forTextStyle: .body)
			cell.textLabel?.adjustsFontForContentSizeCategory = true
			cell.accessoryView = alwaysShowReaderViewSwitch
			cell.selectionStyle = .none
			return cell

		case (0, 3):
			// Folder selection
			let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
			cell.textLabel?.text = NSLocalizedString("Folder", comment: "Folder")
			cell.textLabel?.font = .preferredFont(forTextStyle: .body)
			cell.textLabel?.adjustsFontForContentSizeCategory = true
			cell.detailTextLabel?.text = (container as? DisplayNameProvider)?.nameForDisplay ?? feed.account?.nameForDisplay
			cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
			cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
			cell.accessoryType = .disclosureIndicator
			cell.selectionStyle = .default
			return cell

		case (1, 0):
			// Home Page URL (external link icon to match storyboard)
			let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .default
			// Use external link icon instead of chevron to match storyboard
			let linkImage = UIImage(systemName: "arrow.up.forward.app")
			let linkImageView = UIImageView(image: linkImage)
			linkImageView.tintColor = .secondaryLabel
			cell.accessoryView = linkImageView
			cell.contentView.addSubview(homePageLabel)
			NSLayoutConstraint.activate([
				homePageLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				homePageLabel.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				homePageLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
				homePageLabel.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
			])
			return cell

		case (2, 0):
			// Feed URL
			let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none
			cell.contentView.addSubview(feedURLLabel)
			NSLayoutConstraint.activate([
				feedURLLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				feedURLLabel.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				feedURLLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
				feedURLLabel.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
			])
			return cell

		default:
			fatalError("Unexpected index path")
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let actualSection = actualSectionIndex(for: section)
		switch actualSection {
		case 1:
			return NSLocalizedString("Home Page", comment: "Home Page")
		case 2:
			return NSLocalizedString("Feed URL", comment: "Feed URL")
		default:
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? InspectorIconHeaderView
			headerView?.iconView.iconImage = iconImage
			return headerView
		}
		return nil
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let actualSection = actualSectionIndex(for: indexPath.section)

		if actualSection == 0 && indexPath.row == 3 {
			// Folder selection
			showFolderPicker()
			tableView.deselectRow(at: indexPath, animated: true)
			return
		}

		if actualSection == 1,
			let homePageUrlString = feed.homePageURL,
			let homePageUrl = URL(string: homePageUrlString) {

			let safari = SFSafariViewController(url: homePageUrl)
			safari.modalPresentationStyle = .pageSheet
			present(safari, animated: true) {
				tableView.deselectRow(at: indexPath, animated: true)
			}
		}
	}

	private func showFolderPicker() {
		let folderViewController = AddFeedFolderViewController()
		folderViewController.delegate = self
		folderViewController.initialContainer = container

		let navController = UINavigationController(rootViewController: folderViewController)
		navController.modalPresentationStyle = .formSheet
		present(navController, animated: true)
	}

	// MARK: - Private

	private func actualSectionIndex(for displaySection: Int) -> Int {
		if shouldHideHomePageSection && displaySection >= 1 {
			return displaySection + 1
		}
		return displaySection
	}
}

// MARK: UITextFieldDelegate

extension FeedInspectorViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}

// MARK: UNUserNotificationCenter

extension FeedInspectorViewController {

	@objc func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			let updatedAuthorizationStatus = settings.authorizationStatus
			DispatchQueue.main.async {
				self.authorizationStatus = updatedAuthorizationStatus
				if self.authorizationStatus == .authorized {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	func notificationUpdateErrorAlert() -> UIAlertController {
		let alert = UIAlertController(title: NSLocalizedString("Enable Notifications", comment: "Notifications"),
									  message: NSLocalizedString("Notifications need to be enabled in the Settings app.", comment: "Notifications need to be enabled in the Settings app."), preferredStyle: .alert)
		let openSettings = UIAlertAction(title: NSLocalizedString("Open Settings", comment: "Open Settings"), style: .default) { (action) in
			UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		}
		let dismiss = UIAlertAction(title: NSLocalizedString("Dismiss", comment: "Dismiss"), style: .cancel, handler: nil)
		alert.addAction(openSettings)
		alert.addAction(dismiss)
		alert.preferredAction = openSettings
		return alert
	}

}

// MARK: - AddFeedFolderViewControllerDelegate

extension FeedInspectorViewController: AddFeedFolderViewControllerDelegate {

	func didSelect(container newContainer: Container) {
		guard let sourceContainer = container, sourceContainer !== newContainer else { return }

		BatchUpdate.shared.start()
		sourceContainer.account?.moveFeed(feed, from: sourceContainer, to: newContainer) { [weak self] result in
			BatchUpdate.shared.end()
			Task { @MainActor in
				switch result {
				case .success:
					self?.container = newContainer
					self?.tableView.reloadData()
				case .failure(let error):
					self?.presentError(error)
				}
			}
		}
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
