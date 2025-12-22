//
//  RecipeCardView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if let path = recipe.heroImagePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            }

            HStack {
                if let iconPath = recipe.iconImagePath,
                   let icon = UIImage(contentsOfFile: iconPath) {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text(recipe.siteName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(recipe.title ?? "Loading…")
                .font(.headline)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
