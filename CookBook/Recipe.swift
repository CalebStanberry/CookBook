//
//  Recipe.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import Foundation
import SwiftData

@Model
class Recipe {
    var id: UUID
    var url: String
    var title: String?
    var siteName: String?

    // Cached assets
    var heroImagePath: String?
    var iconImagePath: String?

    // Phase 2+ data
    var ingredients: [Ingredient] = []
    var steps: [String] = []

    var createdAt: Date

    init(url: String) {
        self.id = UUID()
        self.url = url
        self.createdAt = .now
    }
}
