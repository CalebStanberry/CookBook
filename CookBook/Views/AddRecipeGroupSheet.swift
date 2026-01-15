//
//  AddRecipeGroupSheet.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/13/26.
//

import SwiftUI

/// A sheet allowing the user to create a new `RecipeGroup` within a `CookBook`.
/// Displays a simple form for entering the group's name and invokes `onCreate`
/// once confirmed. The presenting view owns state & model context.
struct AddRecipeGroupSheet: View {

    /// The name of the new group, controlled by parent view.
    @Binding var newName: String

    /// Controls presentation / dismissal of the sheet.
    @Binding var isPresented: Bool

    /// Callback invoked when the user confirms creation.
    /// The parent view performs model work (insert, context.save, etc.)
    let onCreate: (String) -> Void

    /// Dismiss environment for convenience.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Name")) {
                    TextField("e.g. Dinner Ideas", text: $newName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Recipe Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        create()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private extension AddRecipeGroupSheet {
    
    /// Handles creation callback and sheet dismissal.
    func create() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        dismissSheet()
    }

    /// Cancels sheet without invoking callback.
    func cancel() {
        dismissSheet()
    }

    /// Dismiss + reset name for better UX on re-opening.
    func dismissSheet() {
        newName = ""
        isPresented = false
        dismiss()
    }
}

#Preview {
    AddRecipeGroupSheet(
        newName: .constant(""),
        isPresented: .constant(true),
        onCreate: { print("Create group:", $0) }
    )
}
