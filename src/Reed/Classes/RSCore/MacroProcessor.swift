//
//  MacroProcessor.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-01.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum MacroProcessorError: Error, Sendable {
    case emptyMacroDelimiter
}

final class MacroProcessor: Sendable {
    let template: String
    let substitutions: [String: String]
    let macroStart: String
    let macroEnd: String

    var renderedText: String {
        processMacros()
    }

    /// Parses a template string and replaces macros with specified values.
    ///
    /// - Returns: A copy of `template` with defined macros replaced by their values.
    ///   Macros with undefined values are left as-is.
    ///
    /// - Parameters:
    ///   - template: The template string to parse, with macros surrounded by `macroStart` and `macroEnd`.
    ///   - substitutions: A dictionary mapping macro keys to their replacement values.
    ///   - macroStart: A string denoting the beginning of a macro.
    ///   - macroEnd: A string denoting the end of a macro.
    ///
    /// - Throws: An error of type `MacroProcessorError`.

    static func renderedText(
        withTemplate template: String,
        substitutions: [String: String],
        macroStart: String = "[[",
        macroEnd: String = "]]"
    ) throws
        -> String
    {
        let processor = try MacroProcessor(
            template: template,
            substitutions: substitutions,
            macroStart: macroStart,
            macroEnd: macroEnd
        )
        return processor.renderedText
    }

    init(template: String, substitutions: [String: String], macroStart: String = "[[", macroEnd: String = "]]") throws {
        if macroStart.isEmpty || macroEnd.isEmpty {
            throw MacroProcessorError.emptyMacroDelimiter
        }

        self.template = template
        self.substitutions = substitutions
        self.macroStart = macroStart
        self.macroEnd = macroEnd
    }
}

nonisolated extension MacroProcessor {
    private func processMacros() -> String {
        var result = String()

        var index = self.template.startIndex

        while true {
            guard let macroStartRange = template[index...].range(of: macroStart) else {
                break
            }

            result.append(contentsOf: self.template[index..<macroStartRange.lowerBound])

            guard let macroEndRange = template[macroStartRange.upperBound...].range(of: macroEnd) else {
                index = macroStartRange.lowerBound
                break
            }

            let key = String(template[macroStartRange.upperBound..<macroEndRange.lowerBound])
            let replacement = self.substitutions[key] ?? "\(self.macroStart)\(key)\(self.macroEnd)"

            result.append(contentsOf: replacement)

            index = macroEndRange.upperBound
        }

        result.append(contentsOf: self.template[index...])

        return result
    }
}
