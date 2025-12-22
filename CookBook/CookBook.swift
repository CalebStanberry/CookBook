//
//  CookBook.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import Foundation
import SwiftData

@Model
class CookBook {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var recipes: [Recipe] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
