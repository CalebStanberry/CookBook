//
//  RecipeHeroThumbnail.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/13/26.
//

import SwiftUI

/// Small thumbnail view for a recipe's hero image.
/// Used in lists or rows where a compact preview is needed.
struct RecipeHeroThumbnail: View {
    @Environment(\.modelContext) private var modelContext   // Access SwiftData context
    @Bindable var recipe: Recipe                            // The recipe being displayed
    @State private var hasAttemptedFetch = false            // Tracks whether a preview fetch has already been attempted

    var body: some View {
        Group {
            // Display local hero image if available
            if let fullPath = recipe.heroImageFullPath,
               let image = UIImage(contentsOfFile: fullPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Placeholder with shimmer for loading state
                Rectangle()
                    .fill(.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo") // Generic photo icon
                            .foregroundStyle(.secondary)
                    }
                    .shimmer(recipe.isFetchingPreview) // Show shimmer while fetching
            }
        }
        .frame(width: 36, height: 36) // Fixed small thumbnail size
        .clipShape(RoundedRectangle(cornerRadius: 6)) // Rounded corners
        .task(id: recipe.id) { // Fetch preview when the view appears
            guard !hasAttemptedFetch else { return }
            hasAttemptedFetch = true
            await fetchPreviewIfNeeded()
        }
    }
    
    // Conditional fetch of hero image preview
    private func fetchPreviewIfNeeded() async {
        // Check if image is already valid
        let imageIsValid: Bool = {
            guard let path = recipe.heroImageFullPath else { return false }
            return FileManager.default.fileExists(atPath: path)
        }()

        // Only fetch if image is missing and fetch hasn't failed
        guard !imageIsValid, !recipe.previewFailed, !recipe.isFetchingPreview else {
            return
        }

        // Trigger PreviewService to fetch image
        PreviewService.shared.fetchPreview(for: recipe, using: modelContext)
    }
    
    // Helper: Load local image (used for debug/logging)
    private func loadImage() -> UIImage? {
        guard let path = recipe.heroImageFullPath else { return nil }

        let exists = FileManager.default.fileExists(atPath: path)
        print("Image exists at path:", exists)

        guard exists else { return nil }

        let image = UIImage(contentsOfFile: path)
        print("Image load success:", image != nil)

        return image
    }
}
