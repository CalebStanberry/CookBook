//
//  PreviewFetcher.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//


import LinkPresentation
import UIKit

func fetchPreview(for recipe: Recipe) {
    guard let url = URL(string: recipe.url) else { return }

    let provider = LPMetadataProvider()
    provider.startFetchingMetadata(for: url) { metadata, error in
        guard let metadata else { return }

        DispatchQueue.main.async { [weak recipe] in
            guard let recipe else { return }
            recipe.title = metadata.title
            recipe.siteName = url.host?
                .replacingOccurrences(of: "www.", with: "")
        }

        if let imageProvider = metadata?.imageProvider {
            imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let image = image as? UIImage else { return }
                let path = saveImage(image)
                DispatchQueue.main.async { [weak recipe] in
                    recipe?.heroImagePath = path
                }
            }
        }

        if let iconProvider = metadata?.iconProvider {
            iconProvider.loadObject(ofClass: UIImage.self) { icon, _ in
                guard let icon = icon as? UIImage else { return }
                let path = saveImage(icon)
                DispatchQueue.main.async {
                    recipe.iconImagePath = path
                }
            }
        }
    }
}
