//
//  CookBookApp.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/20/25.
//

import SwiftUI
import SwiftData

@main
struct CookBookApp: App {
    var body: some Scene {
        WindowGroup {
            CookBookListView()
        }
        .modelContainer(for: [CookBook.self, Recipe.self, Ingredient.self])
    }
}
