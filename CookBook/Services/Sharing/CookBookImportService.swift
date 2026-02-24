//
//  CookBookImportService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/4/26.
//

import SwiftData
import Foundation
import UIKit

/// Responsible for inbound sync only:
/// - receiving remote DTOs
/// - applying changes to local SwiftData models
/// - creating/updating/deleting subtrees
///
/// Outbound sync (push/versioning) intentionally not handled here.
enum CookBookImportService {

    /// Imports a full cookbook subtree.
    /// Handles:
    /// - create on first import
    /// - update on version bump
    /// - ignore if remote version <= local
    /// - ensures relationships + cascading children
    ///
    /// Context must be on the MainActor or explicitly saved afterward.
    static func importCookBook(
        _ dto: ShareableCookBookDTO,
        context: ModelContext
    ) {
        print("Importing cookbook:", dto.name, dto.id)

        let fetch = FetchDescriptor<CookBook>(
            predicate: #Predicate { $0.id == dto.id }
        )

        let existing = try? context.fetch(fetch).first

        if let existing {
            print("Existing cookbook found, version \(existing.version)")

            // Best practice: inbound sync always compares version numbers.
            // Future: could mark conflicts here if user edits locally.
            if dto.version > existing.version {
                print("Updating existing cookbook from v\(existing.version) to v\(dto.version)")
                update(existing, from: dto, context: context)
            } else {
                // NOTE: this covers equality + lower remote version.
                // Future: could optionally detect divergence for conflict UX.
                print("Local version (\(existing.version)) >= remote (\(dto.version))")
            }
        } else {
            print("Creating new cookbook")
            let book = CookBook(from: dto, context: context)
            context.insert(book)

            // Best practice: setting inverse relationships AFTER insertion
            // avoids SwiftData consistency warnings
            for group in book.recipeGroups {
                group.cookBook = book
                for recipe in group.recipes {
                    recipe.recipeGroup = group
                    for ingredient in recipe.ingredients {
                        ingredient.recipe = recipe
                    }
                }
            }

            // Best practice: save once after batch insert/update
            try? context.save()
            print("Cookbook created with \(book.recipeGroups.count) groups")
        }
    }

    /// Creates a recipe group subtree.
    /// Called both during create and update paths.
    ///
    /// NOTE: relationship establishment is deferred up to caller
    internal static func importRecipeGroup(
        _ dto: ShareableRecipeGroupDTO,
        context: ModelContext,
        cookBook: CookBook? = nil
    ) -> RecipeGroup {

        let group = RecipeGroup(
            name: dto.name,
            id: dto.id,
            createdAt: dto.createdAt
        )

        group.cookBook = cookBook

        group.recipes = dto.recipes.map {
            let recipe = importRecipe($0, context: context)
            recipe.recipeGroup = group
            return recipe
        }

        return group
    }

    /// Creates a recipe subtree.
    /// Images are downloaded asynchronously
    private static func importRecipe(
        _ dto: ShareableRecipeDTO,
        context: ModelContext
    ) -> Recipe {

        let recipe = Recipe(
            url: dto.url,
            id: dto.id,
            createdAt: dto.createdAt
        )

        recipe.title = dto.title
        recipe.siteName = dto.siteName
        recipe.steps = dto.steps
        
        recipe.calories = dto.calories
        recipe.totalFat = dto.totalFat
        recipe.totalCarbs = dto.totalCarbs
        recipe.totalProtein = dto.totalProtein
        recipe.totalSugar = dto.totalSugar

        // Since remote data is authoritative here:
        recipe.previewFailed = false
        recipe.isFetchingPreview = false

        recipe.ingredients = dto.ingredients.map {
            let ingredient = importIngredient($0)
            ingredient.recipe = recipe
            return ingredient
        }

        // Best practice: image updates are conditional
        if let imageURL = dto.heroImageURL {

            // Optimization: avoid re-downloading if URL unchanged
            if recipe.heroImageRemoteURL == imageURL.absoluteString {
                return recipe
            }

            recipe.heroImageRemoteURL = imageURL.absoluteString

            Task {
                do {
                    print("📥 Downloading hero image")
                    let path = try await ImageDownloadService.shared.downloadAndSaveImage(from: imageURL)
                    await MainActor.run {
                        recipe.heroImageFileName = savePath(path)
                    }
                } catch {
                    print("Failed to download image:", error)
                }
            }
        }

        return recipe
    }

    /// Leaf import
    private static func importIngredient(
        _ dto: ShareableIngredientDTO
    ) -> Ingredient {

        let ingredient = Ingredient(
            name: dto.name,
            amount: dto.amount,
            id: dto.id
        )

        ingredient.substitutions = dto.substitution
        return ingredient
    }

    /// Updates an existing cookbook subtree in-place.
    /// Handles inserts + updates + deletes for nested groups.
    ///
    /// NOTE: inbound updates are authoritative; no conflict UI yet.
    private static func update(
        _ book: CookBook,
        from dto: ShareableCookBookDTO,
        context: ModelContext
    ) {
        print("🔄 Updating cookbook '\(book.name)'")
        print("   Current groups: \(book.recipeGroups.count)")
        print("   Incoming groups: \(dto.recipeGroups.count)")

        book.name = dto.name
        book.version = dto.version
        book.lastModified = dto.lastModified
        book.isShared = true

        // ID-indexed lookup — avoids O(n²)
        var existingGroupsMap: [UUID: RecipeGroup] = [:]
        for group in book.recipeGroups {
            existingGroupsMap[group.id] = group
        }

        var updatedGroups: [RecipeGroup] = []
        var incomingGroupIDs = Set<UUID>()

        for groupDTO in dto.recipeGroups {
            incomingGroupIDs.insert(groupDTO.id)

            if let existingGroup = existingGroupsMap[groupDTO.id] {
                updateRecipeGroup(existingGroup, from: groupDTO, context: context)
                updatedGroups.append(existingGroup)
            } else {
                let newGroup = importRecipeGroup(groupDTO, context: context, cookBook: book)
                context.insert(newGroup)
                updatedGroups.append(newGroup)
            }
        }

        // Deletes remote removals (authoritative inbound)
        for group in book.recipeGroups where !incomingGroupIDs.contains(group.id) {
            context.delete(group)
        }

        book.recipeGroups = updatedGroups

        for group in book.recipeGroups {
            group.cookBook = book
        }

        do {
            try context.save()
            print("Cookbook updated successfully with \(book.recipeGroups.count) groups")
        } catch {
            print("Failed to save context:", error)
        }
    }

    /// Updates a recipe group subtree in-place.
    /// Same ID-based merge logic as above.
    private static func updateRecipeGroup(
        _ group: RecipeGroup,
        from dto: ShareableRecipeGroupDTO,
        context: ModelContext
    ) {
        group.name = dto.name

        var existingRecipesMap: [UUID: Recipe] = [:]
        for recipe in group.recipes {
            existingRecipesMap[recipe.id] = recipe
        }

        var updatedRecipes: [Recipe] = []
        var incomingRecipeIDs = Set<UUID>()

        for recipeDTO in dto.recipes {
            incomingRecipeIDs.insert(recipeDTO.id)

            if let existingRecipe = existingRecipesMap[recipeDTO.id] {
                updateRecipe(existingRecipe, from: recipeDTO, context: context)
                updatedRecipes.append(existingRecipe)
            } else {
                let newRecipe = importRecipe(recipeDTO, context: context)
                newRecipe.recipeGroup = group
                context.insert(newRecipe)
                updatedRecipes.append(newRecipe)
            }
        }

        for recipe in group.recipes where !incomingRecipeIDs.contains(recipe.id) {
            context.delete(recipe)
        }

        group.recipes = updatedRecipes
    }

    /// Updates a recipe subtree in-place.
    private static func updateRecipe(
        _ recipe: Recipe,
        from dto: ShareableRecipeDTO,
        context: ModelContext
    ) {
        recipe.title = dto.title
        recipe.siteName = dto.siteName
        recipe.steps = dto.steps
        recipe.url = dto.url
        
        recipe.calories = dto.calories
        recipe.totalFat = dto.totalFat
        recipe.totalCarbs = dto.totalCarbs
        recipe.totalProtein = dto.totalProtein
        recipe.totalSugar = dto.totalSugar

        var existingIngredientsMap: [UUID: Ingredient] = [:]
        for ingredient in recipe.ingredients {
            existingIngredientsMap[ingredient.id] = ingredient
        }

        var updatedIngredients: [Ingredient] = []
        var incomingIngredientIDs = Set<UUID>()

        for ingredientDTO in dto.ingredients {
            incomingIngredientIDs.insert(ingredientDTO.id)

            if let existingIngredient = existingIngredientsMap[ingredientDTO.id] {
                existingIngredient.name = ingredientDTO.name
                existingIngredient.amount = ingredientDTO.amount
                existingIngredient.substitutions = ingredientDTO.substitution
                updatedIngredients.append(existingIngredient)
            } else {
                let newIngredient = importIngredient(ingredientDTO)
                newIngredient.recipe = recipe
                context.insert(newIngredient)
                updatedIngredients.append(newIngredient)
            }
        }

        for ingredient in recipe.ingredients where !incomingIngredientIDs.contains(ingredient.id) {
            context.delete(ingredient)
        }

        recipe.ingredients = updatedIngredients

        // NOTE: same image logic as importRecipe, but in update context
        if let imageURL = dto.heroImageURL {
            if recipe.heroImageRemoteURL == imageURL.absoluteString {
                return
            }

            recipe.heroImageRemoteURL = imageURL.absoluteString

            Task {
                do {
                    print("Downloading hero image")
                    let path = try await ImageDownloadService.shared.downloadAndSaveImage(from: imageURL)
                    await MainActor.run {
                        recipe.heroImageFileName = savePath(path)
                    }
                } catch {
                    print("Failed to download image:", error)
                }
            }
        }
    }
}
