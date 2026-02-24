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

    /// Attempts to extract ingredients, steps, and nutrition from raw HTML
    /// - Parameter html: The HTML content of the page
    /// - Returns: A tuple containing ingredients, steps, and optional nutrition data, or `nil` if extraction fails
    static func extract(from html: String) -> (ingredients: [String], steps: [String], nutrition: NutritionData?)? {

        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

        guard let matches = regex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) else {
            return nil
        }

        // Iterate through each JSON-LD block
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = html[range]

            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {

                if let recipe = findRecipeObject(json) {
                    let ingredients = recipe["recipeIngredient"] as? [String] ?? []
                    let steps = parseInstructions(recipe["recipeInstructions"])
                    let nutrition = parseNutrition(recipe["nutrition"])

                    if !ingredients.isEmpty || !steps.isEmpty {
                        return (ingredients, steps, nutrition)
                    }
                }
            }
        }

        return nil
    }

    // Nutrition Data Model

    /// Simple struct to hold parsed nutrition fields
    struct NutritionData {
        let calories: Double?
        let totalFat: Double?
        let totalCarbs: Double?
        let totalProtein: Double?
        let totalSugar: Double?
    }

    // Private Helpers

    /// Recursively searches for a Recipe object
    private static func findRecipeObject(_ json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if dict["@type"] as? String == "Recipe" {
                return dict
            }

            if let graph = dict["@graph"] as? [[String: Any]] {
                return graph.first(where: { $0["@type"] as? String == "Recipe" })
            }
        }

        return nil
    }

    /// Parses recipeInstructions into step strings
    private static func parseInstructions(_ raw: Any?) -> [String] {
        if let steps = raw as? [String] {
            return steps
        }

        if let objects = raw as? [[String: Any]] {
            return objects.compactMap { $0["text"] as? String }
        }

        return []
    }

    /// Parses the nutrition object
    ///
    /// Schema.org example:
    /// "nutrition": {
    ///   "calories": "650 calories",
    ///   "carbohydrateContent": "70 g",
    ///   "proteinContent": "20 g",
    ///   "fatContent": "15 g",
    ///   "sugarContent": "12 g"
    /// }
    private static func parseNutrition(_ raw: Any?) -> NutritionData? {
        guard let dict = raw as? [String: Any] else { return nil }

        let calories = parseNumber(dict["calories"])
        let fat = parseNumber(dict["fatContent"])
        let carbs = parseNumber(dict["carbohydrateContent"])
        let protein = parseNumber(dict["proteinContent"])
        let sugar = parseNumber(dict["sugarContent"])

        // If everything is nil, consider nutrition absent
        if calories == nil && fat == nil && carbs == nil && protein == nil && sugar == nil {
            return nil
        }

        return NutritionData(
            calories: calories,
            totalFat: fat,
            totalCarbs: carbs,
            totalProtein: protein,
            totalSugar: sugar
        )
    }

    /// Extracts a numeric value from typical nutrition strings
    ///
    /// Examples:
    /// "650 calories"  -> 650
    /// "20g"           -> 20
    /// "12 g"          -> 12
    /// "10.5 g"        -> 10.5
    /// nil or bad data -> nil
    private static func parseNumber(_ raw: Any?) -> Double? {
        guard let raw = raw else { return nil }

        if let num = raw as? Double { return num }
        if let num = raw as? Int { return Double(num) }
        if let str = raw as? String {
            return extractLeadingDouble(from: str)
        }

        return nil
    }

    /// Extracts leading double from a string, ignoring trailing units
    private static func extractLeadingDouble(from string: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: string,
                range: NSRange(string.startIndex..., in: string)
              ),
              let range = Range(match.range(at: 1), in: string)
        else {
            return nil
        }

        return Double(String(string[range]))
    }
}
