//
//  IngredientRowView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI

/// Displays a single ingredient in a row, including optional substitution functionality.
struct IngredientRowView: View {
    let ingredient: Ingredient              // The ingredient to display
    let showSubstitutionIcon: Bool          // Whether to show a button for substitutions
    @State private var showSubs = false     // Controls the sheet for showing substitutions

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 12) {

                    // Ingredient Name
                    Text(ingredient.name)
                        .frame(
                            width: showSubstitutionIcon ? geo.size.width * 0.4 : geo.size.width * 0.65,
                            alignment: .leading
                        )
                        // Color blue if JSON-LD data is available, red otherwise
                        .foregroundStyle(Color(ingredient.JSONLDavailable ? .blue : .red))
                    
                    Spacer()

                    // Ingredient Amount
                    Text(ingredient.amount)
                        .foregroundStyle(.secondary)
                        .frame(
                            width: showSubstitutionIcon ? geo.size.width * 0.2 : geo.size.width * 0.3,
                            alignment: .leading
                        )

                    // Substitution Button
                    if showSubstitutionIcon {
                        Button {
                            showSubs.toggle() // Show the substitutions sheet
                        } label: {
                            HStack(spacing: 6) {
                                Text("View")                     // Button text
                                    .foregroundStyle(.primary)   // Ensure text appears
                                
                                Image(systemName: "carrot")      // Fun icon for substitutions
                                    .foregroundStyle(.blue)      // Icon color
                            }
                            .padding(.horizontal, 5)
                            .foregroundColor(.blue)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                )
                                .stroke(.blue, lineWidth: 2)      // Button border
                            )
                        }
                        .frame(height: 20)
                    }
                }
            }
            .frame(height: 24) // Fix height so row doesn't expand
        }
        // Show a sheet with substitutions when the button is tapped
        .sheet(isPresented: $showSubs, onDismiss: {}) {
            self.substitutesSheet
        }
    }

    // Substitutes Sheet
    private var substitutesSheet: some View {
        let subs = ingredient.substitutions

        return NavigationStack {
            // List all substitutions
            List(subs, id: \.self) {
                Text($0)
            }
            .navigationTitle({
                // Sheet title dynamically includes the ingredient name
                let name = ingredient.name
                let title = "Substitutes for " + name
                return title
            }())
        }
    }
}
