//
//  RSMarkdown.swift
//  RSMarkdown
//
//  Created by Brent Simmons on 10/7/25.
//

import Foundation
import Markdown

enum RSMarkdown {
    /// Converts Markdown text to HTML string
    /// - Parameter markdown: The Markdown text to convert
    /// - Returns: HTML string representation of the Markdown
    static func markdownToHTML(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        return HTMLFormatter.format(document)
    }
}
