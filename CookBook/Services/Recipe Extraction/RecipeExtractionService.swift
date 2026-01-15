//
//  RecipeExtractionService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/22/25.
//
//  Handles extraction of recipe ingredients and steps from URLs.
//  Uses LLM extraction as primary method, falling back to JSON-LD parsing.
//

import Foundation

@MainActor
final class RecipeExtractionService {

    static let shared = RecipeExtractionService()
    private init() {}

    /// Extracts recipe data from a URL and updates the given Recipe object.
    /// - Parameters:
    ///   - urlString: The URL of the recipe webpage
    ///   - recipe: The Recipe object to populate
    func extractRecipe(from urlString: String, into recipe: Recipe) async {
        
        // Validate URL
        guard let url = URL(string: urlString) else {
            print("Invalid URL:", urlString)
            return
        }

        // 1. Attempt LLM-based Extraction
        do {
            // Fetch HTML (needed for fallback and LLM context)
            let html = try await HTMLFetcher.fetch(url: url)
            
            // Extract recipe via LLM
            let result = try await LLMRecipeClient().extractRecipe(from: url)

            // Append LLM ingredients to Recipe
            for llmIngredient in result.ingredients {
                let newIngredient = Ingredient(
                    name: llmIngredient.name,
                    amount: llmIngredient.amount,
                    substitutions: llmIngredient.substitutions
                )
                recipe.ingredients.append(newIngredient)
            }
            
            // Set recipe steps
            recipe.steps = result.steps
            
        } catch {
            print("LLM extraction failed for URL:", urlString, error)
        }
        
        // 2. Fallback to JSON-LD Extraction
        if recipe.ingredients.isEmpty {
            do {
                let html = try await HTMLFetcher.fetch(url: url)
                if let jsonLD = JSONLDRecipeExtractor.extract(from: html),
                   !jsonLD.ingredients.isEmpty {
                    
                    // Parse ingredients from JSON-LD
                    let ingredients: [Ingredient] = jsonLD.ingredients.map {
                        IngredientParser.parse($0)
                    }
                    
                    recipe.ingredients = ingredients
                    recipe.steps = jsonLD.steps
                    print("JSON-LD fallback succeeded for URL:", urlString)
                }
            } catch {
                print("JSON-LD fallback failed for URL:", urlString, error)
            }
        }

        // 3. Push changes if recipe is shared
        recipe.pushIfShared()
    }
    
    // Helper

    /// Normalize ingredient names for matching
    /// - Parameter name: Raw ingredient name
    /// - Returns: Lowercased and trimmed name
    func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
