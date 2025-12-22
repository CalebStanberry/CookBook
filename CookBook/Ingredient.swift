//
//  Ingredient.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//


import SwiftData

@Model
class Ingredient {
    var name: String
    var amount: String?

    init(name: String, amount: String? = nil) {
        self.name = name
        self.amount = amount
    }
}