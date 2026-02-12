//
//  SettingsViewController.swift
//  Reed
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import CoreServices
import UIKit
import UniformTypeIdentifiers

final class SettingsViewController: UITableViewController {
    // MARK: - UI Elements

    private lazy var timelineSortOrderSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchTimelineOrder(_:)), for: .valueChanged)
        return toggle
    }()

    private lazy var groupByFeedSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchGroupByFeed(_:)), for: .valueChanged)
        return toggle
    }()

    private lazy var refreshClearsReadArticlesSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchClearsReadArticles(_:)), for: .valueChanged)
        return toggle
    }()

    private lazy var showFullscreenArticlesSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchFullscreenArticles(_:)), for: .valueChanged)
        return toggle
    }()

    private lazy var openLinksInReedSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchBrowserPreference(_:)), for: .valueChanged)
        return toggle
    }()

    private lazy var enableJavaScriptSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(self.switchJavaScriptPreference(_:)), for: .valueChanged)
        return toggle
    }()

    // Section titles
    private let sectionTitles = [
        NSLocalizedString("Notifications, Badge, Data, & More", comment: "Notifications, Badge, Data, & More"),
        NSLocalizedString("Display Options", comment: "Display Options"),
        NSLocalizedString("Feeds", comment: "Feeds"),
        NSLocalizedString("Timeline", comment: "Timeline"),
        NSLocalizedString("Articles", comment: "Articles"),
    ]

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

        title = NSLocalizedString("Settings", comment: "Settings")
        // Use X button to match storyboard
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(self.done(_:))
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        // Register DetailCell with value1 style for showing detail text on right
        self.tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "DetailCell")

        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.timelineSortOrderSwitch.isOn = AppDefaults.shared.timelineSortDirection == .orderedAscending
        self.groupByFeedSwitch.isOn = AppDefaults.shared.timelineGroupByFeed
        self.refreshClearsReadArticlesSwitch.isOn = AppDefaults.shared.refreshClearsReadArticles
        self.showFullscreenArticlesSwitch.isOn = AppDefaults.shared.articleFullscreenAvailable
        self.enableJavaScriptSwitch.isOn = AppDefaults.shared.isArticleContentJavascriptEnabled
        self.openLinksInReedSwitch.isOn = !AppDefaults.shared.useSystemBrowser

        let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
        buildLabel.font = UIFont.systemFont(ofSize: 11.0)
        buildLabel.textColor = UIColor.gray
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        buildLabel.text = "\(appName) \(version) (Build \(build))"
        buildLabel.sizeToFit()
        buildLabel.translatesAutoresizingMaskIntoConstraints = false

        let wrapperView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: buildLabel.frame.width,
            height: buildLabel.frame.height + 10.0
        ))
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.addSubview(buildLabel)
        self.tableView.tableFooterView = wrapperView

        self.tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        5
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: 1 // System Settings
        case 1: 1 // Display Options (Appearance)
        case 2: 2 // Feeds (Import/Export)
        case 3: 4 // Timeline
        case 4: // Articles
            traitCollection.userInterfaceIdiom == .phone ? 3 : 2
        default: 0
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.sectionTitles[section].isEmpty ? nil : self.sectionTitles[section]
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
            cell.accessoryView = self.timelineSortOrderSwitch
            cell.selectionStyle = .none
            return cell
        case (3, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Group by Feed", comment: "Group by Feed")
            cell.accessoryView = self.groupByFeedSwitch
            cell.selectionStyle = .none
            return cell
        case (3, 2):
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString(
                "Refresh to Clear Read Articles",
                comment: "Refresh to Clear Read Articles"
            )
            cell.accessoryView = self.refreshClearsReadArticlesSwitch
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
            cell.textLabel?.text = NSLocalizedString(
                "Enable Full Screen Articles",
                comment: "Enable Full Screen Articles"
            )
            cell.accessoryView = self.showFullscreenArticlesSwitch
            cell.selectionStyle = .none
            return cell
        case (4, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Open Links in App", comment: "Open Links in App")
            cell.accessoryView = self.openLinksInReedSwitch
            cell.selectionStyle = .none
            return cell
        case (4, 2):
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Enable JavaScript", comment: "Enable JavaScript")
            cell.accessoryView = self.enableJavaScriptSwitch
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

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    // MARK: - Actions

    @objc
    func done(_: Any) {
        dismiss(animated: true)
    }

    @objc
    func switchTimelineOrder(_: Any) {
        AppDefaults.shared.timelineSortDirection = self.timelineSortOrderSwitch
            .isOn ? .orderedAscending : .orderedDescending
    }

    @objc
    func switchGroupByFeed(_: Any) {
        AppDefaults.shared.timelineGroupByFeed = self.groupByFeedSwitch.isOn
    }

    @objc
    func switchClearsReadArticles(_: Any) {
        AppDefaults.shared.refreshClearsReadArticles = self.refreshClearsReadArticlesSwitch.isOn
    }

    @objc
    func switchFullscreenArticles(_: Any) {
        AppDefaults.shared.articleFullscreenAvailable = self.showFullscreenArticlesSwitch.isOn
    }

    @objc
    func switchBrowserPreference(_: Any) {
        AppDefaults.shared.useSystemBrowser = !self.openLinksInReedSwitch.isOn
    }

    @objc
    func switchJavaScriptPreference(_: Any) {
        AppDefaults.shared.isArticleContentJavascriptEnabled = self.enableJavaScriptSwitch.isOn
    }

    // MARK: - Notifications

    @objc
    func contentSizeCategoryDidChange() {
        self.tableView.reloadData()
    }
}

// MARK: OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let dataStore = DataStore.shared
        for url in urls {
            dataStore.importOPML(url) { result in
                switch result {
                case .success:
                    break
                case .failure:
                    let title = NSLocalizedString("Import Failed", comment: "Import Failed")
                    let message = NSLocalizedString(
                        "We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.",
                        comment: "Import Failed Message"
                    )
                    self.presentError(title: title, message: message)
                }
            }
        }
    }
}

// MARK: Private

extension SettingsViewController {
    private func importOPML(sourceView _: UIView, sourceRect _: CGRect) {
        // Single account - import directly
        self.importOPMLDocumentPicker()
    }

    private func importOPMLDocumentPicker() {
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

    private func exportOPML(sourceView _: UIView, sourceRect _: CGRect) {
        // Single account - export directly
        self.exportOPMLDocumentPicker()
    }

    private func exportOPMLDocumentPicker() {
        let dataStore = DataStore.shared

        let filename = "Subscriptions.opml"
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let escapedTitle = filename.escapingSpecialXMLCharacters
        let opmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!-- OPML generated by Reed -->
        <opml version="1.1">
        \t<head>
        \t\t<title>\(escapedTitle)</title>
        \t</head>
        <body>
        \(dataStore.OPMLString(indentLevel: 0))\t</body>
        </opml>
        """
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
    override init(style _: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }
}
