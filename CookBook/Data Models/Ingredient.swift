//
//  Ingredient.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//
//  Model representing a single ingredient within a recipe.
//  Supports sharing via DTOs and optional push notifications for shared cookbooks.
//

import SwiftData
import Foundation

/// Represents an ingredient in a recipe, including amount and substitutions.
@Model
class Ingredient {

    /// Unique identifier for the ingredient
    @Attribute(.unique) var id: UUID

    /// Ingredient name (e.g., "Sugar")
    var name: String

    /// Amount or measurement (e.g., "1 cup")
    var amount: String

    /// Flag indicating whether structured data (JSON-LD) is available for this ingredient
    var JSONLDavailable: Bool

    /// Optional substitution suggestions for this ingredient
    var substitutions: [String]

    /// Back-reference to parent recipe
    var recipe: Recipe?

    /// Create a new ingredient with optional name, amount, substitutions, JSON-LD flag, and id
    init(
        name: String = "New Ingredient",
        amount: String = "",
        substitutions: [String] = [],
        JSONLDavailable: Bool = false,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.substitutions = substitutions
        self.JSONLDavailable = JSONLDavailable
    }
}

// Sharing & Sync Helpers

extension Ingredient {

    /// Convert to a DTO suitable for sharing/sync
    func toShareableDTO() -> ShareableIngredientDTO {
        ShareableIngredientDTO(
            id: id,
            name: name,
            amount: amount,
            substitution: substitutions
        )
    }

    /// Mark the parent cookbook as dirty and push if shared
    /// This should eventually be refactored to use centralized change observation
    func pushIfShared() {
        cookBook?.markDirty()
        cookBook?.pushIfShared()
    }

    /// Convenience computed property to access the parent cookbook through the recipe hierarchy
    var cookBook: CookBook? {
        recipe?.recipeGroup?.cookBook
    }
}
