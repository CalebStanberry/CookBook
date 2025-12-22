//
//  CookBookDetailView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI
import SwiftData
import LinkPresentation

struct CookBookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var cookBook: CookBook
    
    @State private var showAddRecipe = false
    @State private var urlText = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(cookBook.recipes) { recipe in
                    Link(destination: URL(string: recipe.url)!) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(cookBook.name)
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
    }
    
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
                    Button("Add") {
                        addRecipe()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddRecipe = false
                        urlText = ""
                    }
                }
            }
        }
    }
    
    private func addRecipe() {
        let recipe = Recipe(url: urlText)
        cookBook.recipes.append(recipe)
        modelContext.insert(recipe)
        
        showAddRecipe = false
        urlText = ""
        
        
        PreviewService.shared.fetchPreview(for: recipe)
        
    }
}

#Preview {
    let container = try! ModelContainer(
        for: CookBook.self,
            Recipe.self,
            Ingredient.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let book = CookBook(name: "Italian Dishes")
    let recipe = Recipe(url: "https://example.com")
    recipe.title = "Pasta Carbonara"
    recipe.siteName = "Serious Eats"

    book.recipes.append(recipe)

    context.insert(book)
    context.insert(recipe)

    return NavigationStack {
        CookBookDetailView(cookBook: book)
    }
    .modelContainer(container)
}
