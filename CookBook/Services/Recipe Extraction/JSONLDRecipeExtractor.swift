//
//  JSONLDRecipeExtractor.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/22/25.
//
//  Extracts recipes from HTML pages using embedded JSON-LD data.
//

import Foundation

/// Utility for extracting recipe data from JSON-LD `<script>` blocks in HTML
struct JSONLDRecipeExtractor {

    // Public API

    /// Attempts to extract ingredients and steps from a raw HTML string
    /// - Parameter html: The HTML content of the page
    /// - Returns: A tuple containing an array of ingredient strings and step strings, or `nil` if extraction fails
    static func extract(from html: String) -> (ingredients: [String], steps: [String])? {

        // Regex pattern to find <script type="application/ld+json"> blocks
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

        guard let matches = regex?.matches(
            in: html,
            options: [],
            range: NSRange(html.startIndex..., in: html)
        ) else { return nil }

        // Iterate through each JSON-LD block
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = html[range]

            // Decode JSON-LD string into a dictionary
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {

                // Attempt to find a recipe object within the JSON-LD
                if let recipe = findRecipeObject(json) {
                    let ingredients = recipe["recipeIngredient"] as? [String] ?? []
                    let steps = parseInstructions(recipe["recipeInstructions"])

                    // Return early if we successfully found ingredients or steps
                    if !ingredients.isEmpty || !steps.isEmpty {
                        return (ingredients, steps)
                    }
                }
            }
        }

        // No valid recipe found
        return nil
    }

    // MPrivate Helpers

    /// Recursively searches a JSON object for a Recipe object
    /// - Parameter json: Decoded JSON object from JSON-LD
    /// - Returns: Dictionary representing the recipe, or `nil` if none found
    private static func findRecipeObject(_ json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            // Direct recipe object
            if dict["@type"] as? String == "Recipe" {
                return dict
            }

            // JSON-LD @graph may contain multiple objects
            if let graph = dict["@graph"] as? [[String: Any]] {
                return graph.first { $0["@type"] as? String == "Recipe" }
            }
        }

        return nil
    }

    /// Parses the `recipeInstructions` field into an array of step strings
    /// - Parameter raw: The raw value of `recipeInstructions` from JSON-LD
    /// - Returns: Array of step strings
    private static func parseInstructions(_ raw: Any?) -> [String] {
        // Instructions may be an array of strings
        if let steps = raw as? [String] {
            return steps
        }

        // Instructions may be an array of objects containing "text"
        if let objects = raw as? [[String: Any]] {
            return objects.compactMap { $0["text"] as? String }
        }

        return []
    }
}
