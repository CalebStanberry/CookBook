//
//  AllRecipesGroupRow.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/13/26.
//

import SwiftUI

/// A view showing a summary row of all recipes across multiple recipe groups.
/// Displays the total recipe count and thumbnails for the newest recipes.
struct AllRecipesGroupRow: View {
    /// The recipe groups to summarize
    let recipeGroups: [RecipeGroup]

    /// Compute the total number of recipes across all groups
    private var totalRecipeCount: Int {
        recipeGroups.reduce(0) { $0 + $1.recipes.count }
    }

    var body: some View {
        HStack(spacing: 12) {
            
            // Left side: Title and recipe count
            VStack(alignment: .leading, spacing: 2) {
                Text("All Recipes")
                    .font(.headline)

                Text("\(totalRecipeCount) recipes")
                    .font(.caption)
                    .foregroundStyle(.secondary) // Subtle text color for the count
            }

            Spacer() // Push thumbnails to the right

            // Right side: Overlapping thumbnails
            HStack(spacing: -8) { // Negative spacing for overlap effect
                ForEach(recipeGroups.newestRecipes) { recipe in
                    RecipeHeroThumbnail(recipe: recipe)
                        .shadow(radius: 1) // Small shadow for visual depth
                }
            }
        }
        .contentShape(Rectangle()) // Make entire HStack tappable
        .animation(.easeInOut, value: totalRecipeCount) // Animate changes in total recipe count
    }
}
