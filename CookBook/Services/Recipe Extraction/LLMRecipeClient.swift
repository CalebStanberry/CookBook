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
/// and parsing the resulting JSON into Ingredient and Step models.
struct LLMRecipeClient {

    // Public API

    /// Extracts ingredients and steps from the provided URL asynchronously
    /// - Parameter url: The URL of the recipe page
    /// - Returns: A tuple of ingredients and step strings
    func extractRecipe(from url: URL) async throws
    -> (ingredients: [Ingredient], steps: [String]) {

        // LLM extraction service endpoint
        let endpoint = URL(string: "https://recipe-extractor.recipe-extractor.workers.dev")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(AppSecrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode the request body
        let body = ["url": url.absoluteString]
        request.httpBody = try JSONEncoder().encode(body)

        // DEBUG: Log request body
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("LLM request body:", bodyString)
        } else {
            print("LLM request body is nil")
        }
        print("Sending URL to LLM:", url.absoluteString)

        // Perform network request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Ensure we have a valid HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("LLM status code:", httpResponse.statusCode)

        // Debug: raw response logging
        if let raw = String(data: data, encoding: .utf8) {
            print("LLM raw response:\n", raw)
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "LLMRecipeClient",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "LLM returned error \(httpResponse.statusCode)"
                ]
            )
        }

        // Decode response JSON into model
        let decoded = try JSONDecoder().decode(LLMRecipeResponse.self, from: data)

        // Map decoded ingredients into internal Ingredient models
        let ingredients = decoded.ingredients.map {
            Ingredient(
                name: $0.name,
                amount: $0.amount ?? "",
                substitutions: $0.substitutions
            )
        }

        return (ingredients, decoded.steps)
    }
}

// Internal Models for Decoding

/// Decodable representation of the LLM JSON response
struct LLMRecipeResponse: Codable {
    let ingredients: [LLMIngredient]
    let steps: [String]
}

/// Decodable representation of a single ingredient from the LLM
struct LLMIngredient: Codable {
    let name: String
    let amount: String?
    let substitutions: [String]
}
