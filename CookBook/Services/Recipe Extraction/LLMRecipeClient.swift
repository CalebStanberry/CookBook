//
//  LLMRecipeClient.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/22/25.
//
//  Client for extracting recipes from web pages using the LLM-based recipe extraction service.
//

import Foundation

/// Client responsible for sending URLs to the LLM extraction service
/// and parsing the resulting JSON into Ingredient, Step, and Nutrition models.
struct LLMRecipeClient {

    // Public API

    /// Extracts recipe details from the provided URL asynchronously.
    /// Returns ingredients, steps, and nutrition totals for the entire recipe.
    func extractRecipe(from url: URL) async throws
    -> (ingredients: [Ingredient], steps: [String], nutrition: Nutrition?) {

        // LLM extraction service endpoint
        let endpoint = URL(string: "https://recipe-extractor.recipe-extractor.workers.dev")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(AppSecrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode request body
        // Payload: { "url": "https://..." }
        let body = ["url": url.absoluteString]
        request.httpBody = try JSONEncoder().encode(body)

        // Debugging (optional)
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("LLM request body:", bodyString)
        }
        print("Sending URL to LLM:", url.absoluteString)

        // Perform network request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("LLM status code:", httpResponse.statusCode)
        if let raw = String(data: data, encoding: .utf8) {
            print("LLM raw response:\n", raw)
        }

        // Handle non-200 responses
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "LLMRecipeClient",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "LLM returned error \(httpResponse.statusCode)"
                ]
            )
        }

        // Decode JSON
        let decoded = try JSONDecoder().decode(LLMRecipeResponse.self, from: data)

        // Map ingredients into your internal model
        let ingredients = decoded.ingredients.map {
            Ingredient(
                name: $0.name,
                amount: $0.amount ?? "",
                substitutions: $0.substitutions
            )
        }

        return (ingredients, decoded.steps, decoded.nutrition)
    }
}

// Internal Decoding Models

/// Decodable representation of the LLM JSON response
struct LLMRecipeResponse: Codable {
    let ingredients: [LLMIngredient]
    let steps: [String]
    let nutrition: Nutrition? /// optional because null is valid + model may omit
}

/// Decodable representation of a single ingredient from the LLM
struct LLMIngredient: Codable {
    let name: String
    let amount: String?
    let substitutions: [String]
}

/// Nutrition totals for the entire recipe
/// Matches the JSON schema defined in the worker prompt
struct Nutrition: Codable {
    let calories: Double?
    let totalFat: Double?
    let totalCarbs: Double?
    let totalProtein: Double?
    let totalSugar: Double?
}
