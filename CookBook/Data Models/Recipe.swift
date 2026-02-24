//
//  Recipe.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//
//  Model representing a single recipe, including ingredients, steps, images, and sharing metadata.
//

import Foundation
import SwiftData
import UIKit

/// Represents a recipe in a recipe group.
@Model
final class Recipe {

    /// Unique identifier for the recipe
    @Attribute(.unique) var id: UUID

    /// Original URL of the recipe source
    var url: String

    /// Recipe title (defaults to "No Title" if not provided)
    var title: String

    /// Name of the source website
    var siteName: String

    /// List of steps or instructions
    var steps: [String] = []

    /// Date the recipe was created
    var createdAt: Date

    /// Flag indicating whether the recipe is deleted locally
    var isDeleted: Bool = false

    /// Parent recipe group
    var recipeGroup: RecipeGroup?

    /// Ingredients associated with this recipe
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient] = []
    
    // Nutritional Information
    
    var calories: Double?
    var totalFat: Double?
    var totalCarbs: Double?
    var totalProtein: Double?
    var totalSugar: Double?

    // Cached Assets

    /// Filename of the hero image stored locally
    var heroImageFileName: String?

    /// Remote URL of hero image for shared cookbooks
    var heroImageRemoteURL: String?

    /// Filename of a small icon image for the recipe
    var iconImageFileName: String?

    /// Flag indicating whether the hero image needs upload (used in shared cookbooks)
    var needsImageUpload: Bool = false

    /// Flag to display shimmer while preview image is being fetched
    var isFetchingPreview: Bool = false

    /// Flag indicating if image preview fetching failed
    var previewFailed: Bool = false

    // Initialization

    /// Initialize a recipe with required URL and optional metadata
    init(
        url: String,
        title: String = "No Title",
        siteName: String = "",
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.siteName = siteName
        self.createdAt = createdAt
    }

    // Computed Properties

    /// Returns true if at least one ingredient has available substitutions
    var substitutionsAvailable: Bool {
        ingredients.contains { !$0.substitutions.isEmpty }
    }
}

// Sharing & Sync Helpers

extension Recipe {

    /// Convert this recipe into a shareable DTO for uploading or syncing
    func toShareableDTO() async throws -> ShareableRecipeDTO {
        let imageURL: URL? = {
            guard let remote = heroImageRemoteURL else { return nil }
            return URL(string: remote)
        }()

        return ShareableRecipeDTO(
            id: id,
            url: url,
            title: title,
            siteName: siteName,
            createdAt: createdAt,
            ingredients: ingredients.map { $0.toShareableDTO() },
            steps: steps,
            calories: calories,
            totalFat: totalFat,
            totalCarbs: totalCarbs,
            totalProtein: totalProtein,
            totalSugar: totalSugar,
            heroImageURL: imageURL
        )
    }

    /// Mark the parent cookbook as dirty and push if shared
    /// Currently called manually from ingredient updates
    func pushIfShared() {
        cookBook?.markDirty()
        cookBook?.pushIfShared()
    }

    /// Convenience computed property to access the parent cookbook through the recipe hierarchy
    var cookBook: CookBook? {
        recipeGroup?.cookBook
    }
}

// Image Paths

extension Recipe {

    /// Full path to the hero image in local storage
    var heroImageFullPath: String? {
        guard let fileName = heroImageFileName else { return nil }

        // Already a full path (legacy support)
        if fileName.hasPrefix("/") { return fileName }

        guard let documentsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }

        return documentsURL.appendingPathComponent(fileName).path
    }

    /// Full path to the icon image in local storage
    var iconImageFullPath: String? {
        guard let fileName = iconImageFileName else { return nil }

        if fileName.hasPrefix("/") { return fileName }

        guard let documentsURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }

        return documentsURL.appendingPathComponent(fileName).path
    }
}

// Allows nutrional info to be displayed neatly with trailing zeroes dropped
extension Double {
    var clean: String {
        self == floor(self) ? String(format: "%.0f", self) : String(self)
    }
}
