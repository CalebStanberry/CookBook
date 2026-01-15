//
//  RecipeDetailView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Displays the details of a single recipe, including hero image, ingredients, steps,
/// and allows editing via `EditRecipeView`.
struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var recipe: Recipe                   // Recipe to display
    @State private var showSubstitutions = false  // Toggle for showing substitutions
    @State var recipeToEdit: Recipe?              // Used to navigate to edit view

    /// Ingredients sorted alphabetically
    private var sortedIngredients: [Ingredient] {
        recipe.ingredients
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Hero Image
                if let path = recipe.heroImageFullPath,
                   let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipped()
                }

                // Title & Site Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.title)
                        .bold()
                    Text(recipe.siteName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Ingredients Section
                ingredientsSection

                Divider()

                // Steps Section
                stepsSection
            }
        }
        .toolbar {
            // Edit button triggers navigation to EditRecipeView
            Button {
                recipeToEdit = recipe
            } label: {
                Text("Edit")
            }
        }
        .refreshable {
            // Pull-to-refresh triggers sync
            Task {
                await CookBookSyncService.shared.syncAllCookBooks(context: modelContext)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $recipeToEdit) { recipe in
            EditRecipeView(recipe: recipe, showAddRecipe: .constant(false))
        }
    }

    // Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients")
                    .font(.headline)

                Spacer()

                Button(action: {
                    withAnimation {
                        showSubstitutions.toggle()
                    }
                }, label: {
                    Text("Substitutions")
                })
                // Only enabled if recipe has substitutions
                .disabled(!recipe.substitutionsAvailable)
                .opacity(recipe.substitutionsAvailable ? 1.0 : 0.4)
            }

            Divider()

            // List of ingredients, showing substitution icon if toggled
            ForEach(sortedIngredients) { ingredient in
                IngredientRowView(ingredient: ingredient, showSubstitutionIcon: showSubstitutions)
            }
        }
        .padding(.horizontal)
    }

    // Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.headline)

            // Display each step with index
            ForEach(recipe.steps.indices, id: \.self) { index in
                Text("\(index + 1). \(recipe.steps[index])")
            }
        }
        .padding(.horizontal)
    }
}
