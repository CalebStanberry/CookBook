//
//  CookBookListView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//


import SwiftUI
import SwiftData

struct CookBookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cookBooks: [CookBook]

    @State private var showAddCookBook = false
    @State private var newCookBookName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(cookBooks) { book in
                    NavigationLink {
                        CookBookDetailView(cookBook: book)
                    } label: {
                        Text(book.name)
                    }
                }
                .onDelete(perform: deleteCookBooks)
            }
            .navigationTitle("CookBooks")
            .toolbar {
                Button {
                    showAddCookBook = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddCookBook) {
                addCookBookSheet
            }
        }
    }

    private var addCookBookSheet: some View {
        NavigationStack {
            Form {
                TextField("CookBook Name", text: $newCookBookName)
            }
            .navigationTitle("New CookBook")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let book = CookBook(name: newCookBookName)
                        modelContext.insert(book)
                        newCookBookName = ""
                        showAddCookBook = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddCookBook = false
                        newCookBookName = ""
                    }
                }
            }
        }
    }

    private func deleteCookBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cookBooks[index])
        }
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

    // Sample data
    let book = CookBook(name: "Preview Cookbook")
    let recipe = Recipe(url: "https://example.com")
    recipe.title = "Preview Recipe"
    recipe.siteName = "Example"

    book.recipes.append(recipe)

    context.insert(book)
    context.insert(recipe)

    return CookBookListView()
        .modelContainer(container)
}
