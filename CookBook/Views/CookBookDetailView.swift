//
//  CookBookDetailView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI
import SwiftData
import LinkPresentation

/// Shows the content of a single CookBook and supports:
/// - Viewing recipe groups
/// - Creating recipe groups
/// - Sharing cookbooks
/// - Triggering preview sync for hero images
struct CookBookDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var cookBook: CookBook
    
    @State private var showAddRecipeGroup = false
    @State private var newRecipeGroupName = ""
    @State private var showShareSheet = false

    var body: some View {
        List {
            NavigationLink {
                AllRecipesView(allRecipes: cookBook.recipeGroups)
            } label: {
                AllRecipesGroupRow(recipeGroups: cookBook.recipeGroups)
            }
            Section {
                ForEach(cookBook.recipeGroups) { group in
                    NavigationLink {
                        RecipeGroupView(recipeGroup: group)
                    } label: {
                        RecipeGroupRow(recipeGroup: group)
                    }
                }
                .onDelete(perform: deleteRecipeGroups)
            }
        }
        .navigationTitle(cookBook.name)
        .toolbar {
            shareButton
            addGroupButton
        }
        .sheet(isPresented: $showAddRecipeGroup) {
            AddRecipeGroupSheet(
                newName: $newRecipeGroupName,
                isPresented: $showAddRecipeGroup,
                onCreate: createRecipeGroup
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [
                CookBookSyncService.shared.shareURL(for: cookBook)
            ])
        }
    }

    private var shareButton: some View {
        Button {
            Task {
                await shareCookBook()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }

    private var addGroupButton: some View {
        Button {
            showAddRecipeGroup = true
        } label: {
            Image(systemName: "plus")
        }
    }

    @MainActor
    func createRecipeGroup(_ name: String) {
        let group = RecipeGroup(name: name)
        group.cookBook = cookBook

        // Persist
        modelContext.insert(group)

        // Update UI model
        cookBook.recipeGroups.append(group)

        // Push to collaborators if shared
        if cookBook.isShared {
            group.pushIfShared()
        }

        newRecipeGroupName = ""
    }

    private func deleteRecipeGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = cookBook.recipeGroups[index]

            // Remove from SwiftData
            modelContext.delete(group)
        }

        cookBook.recipeGroups.remove(atOffsets: offsets)

        if cookBook.isShared {
            cookBook.pushIfShared()
        }
    }

    @MainActor
    private func shareCookBook() async {
        cookBook.isShared = true

        do {
            // Pre-prepare images (for collaborators)
            try await CookBookSyncService.shared.prepareImagesForSharing(cookBook)

            // Build sharable DTO + push
            let dto = try await cookBook.toShareableDTO()
            try await CookBookSyncService.shared.push(dto)

            showShareSheet = true

        } catch {
            print("Failed to share cookbook:", error)
        }
    }
}
