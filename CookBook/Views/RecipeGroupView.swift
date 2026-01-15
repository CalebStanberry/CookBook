//
//  RecipeGroupView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/28/25.
//
//  Displays recipes in a group with grid layout, allows adding/editing/deleting.
//  Supports manual and URL-based recipe addition, preview fetching, and sync.
//

import SwiftUI
import SwiftData

struct RecipeGroupView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Bindable var recipeGroup: RecipeGroup
    
    @State private var showAddRecipe = false
    @State private var urlText = ""
    @State private var manuallyCreatedRecipe: Recipe?
    @State private var recipeToEdit: Recipe?
    
    // Sorted, non-deleted recipes for display
    private var sortedRecipes: [Recipe] {
        recipeGroup.recipes
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeCardView(recipe: recipe, cardWidth: 140)
                            .onAppear {
                                // Auto-fetch preview if file missing
                                refreshPreviewIfNeeded(recipe)
                            }
                            .contextMenu {
                                Button {
                                    recipeToEdit = recipe
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    delete(recipe)
                                } label: {
                                    Label("Delete Recipe", systemImage: "trash")
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .refreshable {
                Task {
                    await CookBookSyncService.shared.syncAllCookBooks(context: modelContext)
                }
            }
        }
        .navigationTitle(recipeGroup.name)
        .toolbar {
            Button {
                showAddRecipe = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            addRecipeSheet
        }
        .navigationDestination(item: $recipeToEdit) { recipe in
            EditRecipeView(recipe: recipe, showAddRecipe: $showAddRecipe)
        }
    }
    
    // Add Recipe Sheet
    
    private var addRecipeSheet: some View {
        NavigationStack {
            Form {
                TextField("Recipe URL", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Add Recipe")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addRecipe() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddRecipe = false
                        urlText = ""
                    }
                }
            }
            
            Button {
                addRecipeManually()
            } label: {
                Text("Add Manually")
                    .font(.headline)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding()
            .navigationDestination(item: $manuallyCreatedRecipe) { recipe in
                EditRecipeView(recipe: recipe, showAddRecipe: $showAddRecipe)
            }
        }
    }
    
    // Recipe Management
    
    private func addRecipe() {
        let recipe = Recipe(url: urlText)
        recipe.recipeGroup = recipeGroup
        recipeGroup.recipes.append(recipe)
        modelContext.insert(recipe)
        
        showAddRecipe = false
        urlText = ""
        
        // Fetch preview if not already available
        if recipe.heroImageFullPath == nil && !recipe.previewFailed {
            PreviewService.shared.fetchPreview(for: recipe, using: modelContext)
            recipe.needsImageUpload = true
        }

        // Extract recipe details asynchronously
        Task {
            await RecipeExtractionService.shared.extractRecipe(from: recipe.url, into: recipe)
        }
    }
    
    private func addRecipeManually() {
        let newRecipe = Recipe(url: "", title: "New Recipe")
        newRecipe.recipeGroup = recipeGroup
        let newIngredient = Ingredient()
        newRecipe.ingredients.append(newIngredient)
        newRecipe.steps.append("New Step")
        
        recipeGroup.recipes.append(newRecipe)
        modelContext.insert(newRecipe)
        modelContext.insert(newIngredient)
        newRecipe.pushIfShared() // Sync with shared CookBook if applicable
        
        manuallyCreatedRecipe = newRecipe
    }
    
    private func delete(_ recipe: Recipe) {
        // Remove any stored images
        if let path = recipe.heroImageFullPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        if let path = recipe.iconImageFullPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        // Remove from context and group
        withAnimation {
            recipeGroup.recipes.removeAll { $0.id == recipe.id }
            modelContext.delete(recipe)
            try? modelContext.save()
        }
        
        recipeGroup.pushIfShared()
    }
    
    private func refreshPreviewIfNeeded(_ recipe: Recipe) {
        guard let path = recipe.heroImageFullPath else { return }
        if !FileManager.default.fileExists(atPath: path) {
            recipe.heroImageFileName = nil
            recipe.iconImageFileName = nil
            recipe.previewFailed = false
            
            PreviewService.shared.fetchPreview(for: recipe, using: modelContext)
        }
    }
}

// All Recipes Overview

struct AllRecipesView: View {
    @Environment(\.modelContext) private var modelContext
    let allRecipes: [RecipeGroup]
    @State private var recipeToDelete: (recipe: Recipe, group: RecipeGroup)?
    @State private var showDeleteConfirmation = false
    @State private var selectedRecipe: Recipe?
    
    private var sortedRecipeGroups: [RecipeGroup] {
        allRecipes.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            ForEach(sortedRecipeGroups) { group in
                Section(group.name) {
                    if group.recipes.isEmpty {
                        Text("No Recipes")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(group.recipes.sorted { $0.createdAt > $1.createdAt }) { recipe in
                                    RecipeCardView(recipe: recipe, cardWidth: 140, imageHeight: 160)
                                        .onTapGesture { selectedRecipe = recipe }
                                        .onLongPressGesture {
                                            recipeToDelete = (recipe, group)
                                            showDeleteConfirmation = true
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .refreshable {
            Task {
                await CookBookSyncService.shared.syncAllCookBooks(context: modelContext)
            }
        }
        .navigationTitle("All Recipes")
        .navigationDestination(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .confirmationDialog(
            "Delete Recipe",
            isPresented: $showDeleteConfirmation,
            presenting: recipeToDelete
        ) { item in
            Button("Delete", role: .destructive) { delete(item.recipe, from: item.group) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Are you sure you want to delete this recipe?")
        }
    }

    private func delete(_ recipe: Recipe, from group: RecipeGroup) {
        group.recipes.removeAll { $0.id == recipe.id }
        modelContext.delete(recipe)
        group.pushIfShared()
    }
}
