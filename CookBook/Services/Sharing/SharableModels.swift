//
//  ShareableModels.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/4/26.
//
//  DTOs used for cross-device cookbook synchronization and sharing.
//
//  These models represent the network/public shape for CookBook domain entities.
//
//  IMPORTANT:
//  - Domain models should convert to/from DTOs via adapter logic in Import/Export services.
//  - Changes to these structures constitute an API version change.
//

import Foundation

/// Intended for full replacements rather than incremental diffs.
struct ShareableCookBookDTO: Codable {
    let id: UUID
    let name: String

    /// Incremented on local change. Required for conflict resolution.
    let version: Int

    /// Updated each time the cookbook changes.
    let lastModified: Date

    /// Timestamp used for sort, creation history, and analytics.
    let createdAt: Date

    /// Indicates if this cookbook is shared publicly.
    /// (Used by UI and worker endpoint logic.)
    let isShared: Bool

    /// Recipe groups are included inline for convenience.
    let recipeGroups: [ShareableRecipeGroupDTO]
}

/// Logical grouping of recipes (ex "Breakfast", "Italian", "Desserts").
struct ShareableRecipeGroupDTO: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let recipes: [ShareableRecipeDTO]
}

/// Individual recipe with source URL, scraped metadata, ordering, and hero asset.
struct ShareableRecipeDTO: Codable {
    let id: UUID

    /// Valid recipe URL
    let url: String

    /// Recipe title extracted from scraper or user override.
    let title: String

    /// ex “NYTimes Cooking”, “AllRecipes”, “Serious Eats”.
    let siteName: String

    /// Timestamp for sorting/history/order in sync pipeline.
    let createdAt: Date

    /// Ingredients extracted and/or user edited.
    let ingredients: [ShareableIngredientDTO]

    /// Step instructions in ordered list format.
    let steps: [String]
    
    // Nutrional Information for the recipe
    let calories: Double?
    let totalFat: Double?
    let totalCarbs: Double?
    let totalProtein: Double?
    let totalSugar: Double?

    /// Optional remote URL for hero image.
    /// Imported via ImageDownloadService and stored locally as path.
    let heroImageURL: URL?
}

/// Substitution allows multiple alternatives.
struct ShareableIngredientDTO: Codable {
    let id: UUID
    let name: String
    let amount: String

    /// ex ["coconut milk", "almond milk"]
    let substitution: [String]
}
