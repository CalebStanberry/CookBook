//
//  RecipeGroup.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/28/25.
//
//  Model representing a group of recipes within a cookbook.
//

import Foundation
import SwiftData

/// Represents a collection of recipes, belonging to a single cookbook.
@Model
class RecipeGroup {

    /// Unique identifier for the recipe group
    @Attribute(.unique) var id: UUID

    /// Name of the group (e.g., "Desserts", "Main Courses")
    var name: String

    /// Date the group was created
    var createdAt: Date

    /// Recipes contained in this group
    @Relationship(deleteRule: .cascade, inverse: \Recipe.recipeGroup)
    var recipes: [Recipe] = []

    /// Parent cookbook
    var cookBook: CookBook?

    // Initialization

    /// Initialize a recipe group with a name and optional ID / creation date
    init(name: String, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// Computed Properties & Helpers

extension RecipeGroup {

    /// Returns the 3 most recently added recipes, used for previews
    var newestRecipes: [Recipe] {
        recipes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { $0 }
    }

    /// Convert this recipe group into a shareable DTO for syncing or pushing
    func toShareableDTO() async throws -> ShareableRecipeGroupDTO {
        var recipeDTOs: [ShareableRecipeDTO] = []

        for recipe in recipes {
            let dto = try await recipe.toShareableDTO()
            recipeDTOs.append(dto)
        }

        return ShareableRecipeGroupDTO(
            id: id,
            name: name,
            createdAt: createdAt,
            recipes: recipeDTOs
        )
    }

    /// Mark the parent cookbook as dirty and push if shared
    /// Currently called manually from RecipeGroup updates
    func pushIfShared() {
        cookBook?.markDirty()
        cookBook?.pushIfShared()
    }
}
