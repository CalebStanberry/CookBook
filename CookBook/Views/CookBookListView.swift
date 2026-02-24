//
//  CookBookListView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI
import SwiftData

/// Displays a list of CookBooks and supports:
/// - Creation
/// - Deletion (with confirmation)
/// - Navigation to detail view
/// - Local + shared syncing with backend
///
/// This acts as the primary entry point for user data.
struct CookBookListView: View {

    @Environment(\.modelContext) private var modelContext
    
    /// Fetches all CookBooks from SwiftData.
    /// Sorted manually
    @Query private var cookBooks: [CookBook]

    private var sortedCookBooks: [CookBook] {
        cookBooks.sorted { $0.createdAt > $1.createdAt }
    }

    @State private var showAddCookBook = false
    @State private var newCookBookName = ""
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteBook: CookBook?

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ShoppingListView()
                } label: {
                    Label("Shopping List", systemImage: "cart")
                }

                ForEach(sortedCookBooks) { book in
                    NavigationLink {
                        CookBookDetailView(cookBook: book)
                    } label: {
                        CookBookRow(book: book)
                    }
                }
                .onDelete(perform: handleDelete)
            }
            .onAppear(perform: onAppear)
            .refreshable(action: refreshCookBooks)
            .navigationTitle("CookBooks")
            .toolbar {
                Button(action: { showAddCookBook = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddCookBook) {
                AddCookBookSheet(
                    newCookBookName: $newCookBookName,
                    isPresented: $showAddCookBook,
                    onCreate: createCookBook
                )
            }
        }
        .confirmationDialog(
            "Delete Cookbook?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pending = pendingDeleteBook {
                    Task { await deleteCookBook(pending) }
                    pendingDeleteBook = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingDeleteBook = nil
            }
        } message: {
            if let pending = pendingDeleteBook {
                Text(
                    pending.isShared
                    ? "This shared cookbook will be removed for all collaborators."
                    : "This cookbook will be permanently deleted."
                )
            }
        }
    }

    private func onAppear() {
        CookBookSyncService.shared.startAutoSync(context: modelContext)
    }

    private func refreshCookBooks() async {
        await CookBookSyncService.shared.syncAllCookBooks(context: modelContext)
    }

    private func handleDelete(_ offsets: IndexSet) {
        if let index = offsets.first {
            pendingDeleteBook = sortedCookBooks[index]
            showDeleteConfirmation = true
        }
    }

    private func createCookBook() {
        guard !newCookBookName.isEmpty else { return }

        let book = CookBook(name: newCookBookName)
        modelContext.insert(book)

        newCookBookName = ""
    }

    @MainActor
    private func deleteCookBook(_ book: CookBook) async {
        // Remove remotely if shared
        if book.isShared {
            do {
                try await CookBookSyncService.shared.deleteSharedCookBook(book)
            } catch {
                print("Remote delete failed:", error)
            }
        }

        // Remove locally
        modelContext.delete(book)
    }
}

private struct CookBookRow: View {
    let book: CookBook

    var body: some View {
        HStack {
            Text(book.name)

            Spacer()

            if book.isShared {
                Image(systemName: "person.2.fill")
            }
        }
    }
}

private struct AddCookBookSheet: View {
    @Binding var newCookBookName: String
    @Binding var isPresented: Bool

    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("CookBook Name", text: $newCookBookName)
            }
            .navigationTitle("New CookBook")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate()
                        isPresented = false
                    }
                    .disabled(newCookBookName.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newCookBookName = ""
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: CookBook.self,
                Recipe.self,
                Ingredient.self,
                ShoppingItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = container.mainContext
        let book = CookBook(name: "Preview Cookbook")
        context.insert(book)

        return CookBookListView()
            .modelContainer(container)

    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
