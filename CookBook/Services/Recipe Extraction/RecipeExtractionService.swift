//
//  RecipeExtractionService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/22/25.
//
//  Handles extraction of recipe ingredients, steps, and nutrition from URLs.
//  Primary path: LLM extraction.
//  Fallback: JSON-LD.
//  Nutrition rules:
//   - LLM returns total recipe nutrition via heuristics or best estimates.
//   - JSON-LD may override only if explicit nutrition is present.
//   - Missing nutrition fields remain nil.
//

import Foundation

@MainActor
final class RecipeExtractionService {

    static let shared = RecipeExtractionService()
    private init() {}

    /// Extracts recipe data from a URL and updates the given Recipe object.
    /// - Parameters:
    ///   - urlString: The URL of the recipe webpage.
    ///   - recipe: The Recipe object to populate.
    func extractRecipe(from urlString: String, into recipe: Recipe) async {
        
        // Validate URL
        guard let url = URL(string: urlString) else {
            print("Invalid URL:", urlString)
            return
        }

        // Fetch HTML once (used for LLM context + JSON-LD fallback)
        let html: String
        do {
            html = try await HTMLFetcher.fetch(url: url)
        } catch {
            print("Failed to fetch HTML:", error)
            return
        }

        //
        // 1. Primary: LLM Extraction
        //
        do {
            let llmResult = try await LLMRecipeClient().extractRecipe(from: url)

            // Ingredients
            recipe.ingredients.append(contentsOf: llmResult.ingredients)

            // Steps
            recipe.steps = llmResult.steps

            // Nutrition (if present)
            // NOTE: LLM returns `.null` for unknown categories, not omitted
            recipe.calories = llmResult.nutrition?.calories
            recipe.totalFat = llmResult.nutrition?.totalFat
            recipe.totalCarbs = llmResult.nutrition?.totalCarbs
            recipe.totalProtein = llmResult.nutrition?.totalProtein
            recipe.totalSugar = llmResult.nutrition?.totalSugar

            print("LLM extraction succeeded for URL:", urlString)

        } catch {
            print("LLM extraction failed for URL:", urlString, error)
        }

        //
        // 2. Fallback: JSON-LD (only if missing core fields)
        //
        do {
            if recipe.ingredients.isEmpty || recipe.steps.isEmpty {
                if let jsonLD = JSONLDRecipeExtractor.extract(from: html) {
                    
                    // Fallback ingredients
                    if recipe.ingredients.isEmpty && !jsonLD.ingredients.isEmpty {
                        recipe.ingredients = jsonLD.ingredients.map { IngredientParser.parse($0) }
                    }

                    // Fallback steps
                    if recipe.steps.isEmpty && !jsonLD.steps.isEmpty {
                        recipe.steps = jsonLD.steps
                    }

                    // Fallback nutrition:
                    // JSON-LD nutrition typically provides per-serving or per-item
                    // We intentionally do NOT try to infer servings here.
                    // Only override if explicit values exist.
                    if let ldNut = jsonLD.nutrition {

                        if recipe.calories == nil { recipe.calories = ldNut.calories }
                        if recipe.totalFat == nil { recipe.totalFat = ldNut.totalFat }
                        if recipe.totalCarbs == nil { recipe.totalCarbs = ldNut.totalCarbs }
                        if recipe.totalProtein == nil { recipe.totalProtein = ldNut.totalProtein }
                        if recipe.totalSugar == nil { recipe.totalSugar = ldNut.totalSugar }
                    }

                    print("JSON-LD fallback succeeded for URL:", urlString)
                }
            }
        } catch {
            print("JSON-LD fallback failed for URL:", urlString, error)
        }

        // ===========================================================
        // 3. Commit updates if shared recipe
        // ===========================================================
        recipe.pushIfShared()
    }
    
    /// Small helper for matching ingredient names
    func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/*
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
*/
