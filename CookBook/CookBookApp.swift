//
//  CookBookApp.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/20/25.
//

import SwiftUI
import SwiftData

/// Main entry point for the CookBook application.
///
/// Responsible for:
/// - Initializing SwiftData storage
/// - Injecting model container into the scene hierarchy
/// - Hosting the root view
@main
struct CookBookApp: App {

    /// Shared SwiftData container defining all persisted models.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: CookBook.self,
                    RecipeGroup.self,
                    Recipe.self,
                    Ingredient.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
