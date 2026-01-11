//
//  AboutViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

final class AboutViewController: UITableViewController {

	private lazy var aboutTextView: UITextView = createTextView()
	private lazy var creditsTextView: UITextView = createTextView()
	private lazy var thanksTextView: UITextView = createTextView()
	private lazy var dedicationTextView: UITextView = createTextView()

	private let sectionTitles = [
		NSLocalizedString("About", comment: "About"),
		NSLocalizedString("Credits", comment: "Credits"),
		NSLocalizedString("Thanks", comment: "Thanks"),
		NSLocalizedString("Dedication", comment: "Dedication")
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

		title = NSLocalizedString("About", comment: "About")

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextViewCell")

		configureCell(file: "About", textView: aboutTextView)
		configureCell(file: "Credits", textView: creditsTextView)
		configureCell(file: "Thanks", textView: thanksTextView)
		configureCell(file: "Dedication", textView: dedicationTextView)

		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = NSLocalizedString("Copyright © 2002-2025 Brent Simmons", comment: "Copyright")
		buildLabel.numberOfLines = 0
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false

		let wrapperView = UIView(frame: CGRect(x: 0, y: 0, width: buildLabel.frame.width, height: buildLabel.frame.height + 10.0))
		wrapperView.translatesAutoresizingMaskIntoConstraints = false
		wrapperView.addSubview(buildLabel)
		tableView.tableFooterView = wrapperView
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 4
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sectionTitles[section]
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "TextViewCell", for: indexPath)
		cell.contentView.subviews.forEach { $0.removeFromSuperview() }
		cell.selectionStyle = .none

		let textView: UITextView
		switch indexPath.section {
		case 0:
			textView = aboutTextView
		case 1:
			textView = creditsTextView
		case 2:
			textView = thanksTextView
		case 3:
			textView = dedicationTextView
		default:
			fatalError("Unexpected section")
		}

		cell.contentView.addSubview(textView)
		NSLayoutConstraint.activate([
			textView.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
			textView.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
			textView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
			textView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
		])

		return cell
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}

}

private extension AboutViewController {

	func createTextView() -> UITextView {
		let textView = UITextView()
		textView.isEditable = false
		textView.isScrollEnabled = false
		textView.backgroundColor = .clear
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		textView.translatesAutoresizingMaskIntoConstraints = false
		return textView
	}

	func configureCell(file: String, textView: UITextView) {
		let url = Bundle.main.url(forResource: file, withExtension: "rtf")!
		let string = try! NSAttributedString(url: url, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
		textView.attributedText = string
		textView.textColor = UIColor.label
		textView.adjustsFontForContentSizeCategory = true
		textView.font = .preferredFont(forTextStyle: .body)
	}

}
