//
//  IngredientParser.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/25/25.
//
//  Parses raw JSON-LD ingredient strings into structured Ingredient objects.
//

import Foundation

/// Utility for parsing raw ingredient strings from JSON-LD or web sources
struct IngredientParser {

    /// Parses a raw ingredient string into a structured `Ingredient` object
    /// - Parameter raw: The raw ingredient text (e.g., "1 cup sugar")
    /// - Returns: A `Ingredient` with separated `name` and `amount`
    static func parse(_ raw: String) -> Ingredient {
        // Remove bullet points and trim whitespace
        let cleaned = raw
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Regex pattern to extract: [quantity + fraction] [unit] [ingredient name]
        let pattern = #"^([\d¼½¾⅓⅔⅛⅜⅝⅞\/\.\-\s]+)?\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|ounces?|oz|pounds?|lbs?|grams?|ml|[gG](?![a-zA-Z])|[lL](?![a-zA-Z]))?\s*(.*)$"#

        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: cleaned.utf16.count)

        // Attempt to match the pattern
        if let match = regex?.firstMatch(in: cleaned, range: range) {

            // Extract individual capture groups
            let amountPart = substring(cleaned, match.range(at: 1))
            let unitPart   = substring(cleaned, match.range(at: 2))
            let namePart   = substring(cleaned, match.range(at: 3))

            // Combine amount and unit
            let amount = [amountPart, unitPart]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)

            return Ingredient(
                name: namePart?.trimmingCharacters(in: .whitespaces) ?? cleaned,
                amount: amount,
                JSONLDavailable: true
            )
        }

        // Fallback if regex fails: treat entire string as ingredient name
        return Ingredient(name: cleaned, amount: "", JSONLDavailable: true)
    }

    // Private Helpers

    /// Safely extracts a substring from a `String` using an `NSRange`
    /// - Parameters:
    ///   - text: The source string
    ///   - range: The `NSRange` from regex capture
    /// - Returns: Substring if valid, otherwise `nil`
    private static func substring(_ text: String, _ range: NSRange) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
