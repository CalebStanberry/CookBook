//
//  RecipeCardView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//

import SwiftUI

/// Displays a single recipe card including hero image, site info, and recipe title.
struct RecipeCardView: View {
    @Bindable var recipe: Recipe                 // Recipe to display
    @State private var isFetching: Bool = false  // Tracks fetching state for the hero image
    var cardWidth: CGFloat = .infinity           // Width of the card
    var imageHeight: CGFloat = 120               // Height of hero image

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Hero Image
            RecipeHeroImageView(
                recipe: recipe,
                width: cardWidth,
                height: imageHeight,
                isFetching: $isFetching
            )

            // Site Info
            HStack(spacing: 6) {
                siteIcon                        // Optional icon for the website
                Text(recipe.siteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: cardWidth)

            // Recipe Title
            Text(recipe.title)
                .font(.headline)
                .lineLimit(2)
                .frame(width: cardWidth, height: titleHeight, alignment: .top)
        }
        .padding()
        .frame(height: totalCardHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground)) // Card background
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Sync fetching state with recipe
            isFetching = recipe.isFetchingPreview
        }
        .onChange(of: recipe.isFetchingPreview) { _, newValue in
            isFetching = newValue
        }
    }

    // Layout Constants
    private let verticalSpacing: CGFloat = 8
    private let paddingSize: CGFloat = 12

    /// Height for the recipe title label (2 lines)
    private var titleHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .headline).lineHeight * 2 + 2
    }

    /// Total card height including image, site row, title, spacing, and padding
    private var totalCardHeight: CGFloat {
        imageHeight
        + verticalSpacing
        + 16     // site row height
        + verticalSpacing
        + titleHeight
        + paddingSize * 2
    }

    /// Optional site icon view
    private var siteIcon: some View {
        Group {
            if let iconPath = recipe.iconImageFullPath,
               let icon = UIImage(contentsOfFile: iconPath) {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
    }
}

/// Handles the hero image display with placeholders for different states.
struct RecipeHeroImageView: View {
    @Bindable var recipe: Recipe
    let width: CGFloat
    let height: CGFloat
    @Binding var isFetching: Bool

    var body: some View {
        Group {
            if let path = recipe.heroImageFullPath,
               fileExists(at: path),
               let image = UIImage(contentsOfFile: path) {
                // Local image exists
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if recipe.heroImageRemoteURL != nil {
                // Remote image is being downloaded
                placeholderWithProgress
            } else if isFetching {
                // Still fetching preview from PreviewService
                placeholderWithShimmer
            } else if recipe.previewFailed {
                // Failed to fetch image
                placeholderWithError
            } else {
                // Default placeholder
                defaultPlaceholder
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(8)
    }

    // Placeholder Views

    /// Show progress indicator for ongoing download
    private var placeholderWithProgress: some View {
        Rectangle()
            .fill(.secondary.opacity(0.15))
            .overlay {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    /// Show shimmer effect while fetching
    private var placeholderWithShimmer: some View {
        Rectangle()
            .fill(.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .shimmer(true)
    }

    /// Show error icon if fetch failed
    private var placeholderWithError: some View {
        Rectangle()
            .fill(.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
    }

    /// Default placeholder if no image available
    private var defaultPlaceholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}

// Helper

/// Check if a file exists at a given path
func fileExists(at path: String?) -> Bool {
    guard let path = path else { return false }
    return FileManager.default.fileExists(atPath: path)
}
