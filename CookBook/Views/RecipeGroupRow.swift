//
//  RecipeGroupRow.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/13/26.
//

import SwiftUI

/// Displays a horizontal row summarizing a recipe group, showing the group name,
/// total recipe count, and a small preview of the newest recipes.
struct RecipeGroupRow: View {
    let recipeGroup: RecipeGroup  // The recipe group to display

    var body: some View {
        HStack(spacing: 12) {
            // Group Info
            VStack(alignment: .leading, spacing: 2) {
                // Group name (headline font)
                Text(recipeGroup.name)
                    .font(.headline)

                // Number of recipes in the group (caption font, secondary color)
                Text("\(recipeGroup.recipes.count) recipes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer() // Pushes recipe thumbnails to the trailing edge

            // Preview of newest recipes
            HStack(spacing: -8) {
                ForEach(recipeGroup.newestRecipes) { recipe in
                    RecipeHeroThumbnail(recipe: recipe)
                        .shadow(radius: 1) // Subtle shadow for thumbnail
                }
            }
        }
        .contentShape(Rectangle()) // Makes the whole row tappable
        .animation(.easeInOut, value: recipeGroup.recipes.count) // Smoothly animate count changes
    }
}
