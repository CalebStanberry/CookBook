import Foundation
import LinkPresentation
import UIKit

@MainActor
final class PreviewService {

    static let shared = PreviewService()
    private init() {}

    func fetchPreview(for recipe: Recipe) {
        guard let url = URL(string: recipe.url) else { return }

        let provider = LPMetadataProvider()

        provider.startFetchingMetadata(for: url) { metadata, error in
            guard let metadata else {
                print("Metadata fetch failed:", error ?? "")
                return
            }

            DispatchQueue.main.async {
                recipe.title = metadata.title
                recipe.siteName = url.host?
                    .replacingOccurrences(of: "www.", with: "")
            }

            // Hero image
            if let imageProvider = metadata.imageProvider {
                imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    guard let image = image as? UIImage else { return }
                    if let path = saveImage(image) {
                        DispatchQueue.main.async {
                            recipe.heroImagePath = path
                        }
                    }
                }
            }

            // Favicon
            if let iconProvider = metadata.iconProvider {
                iconProvider.loadObject(ofClass: UIImage.self) { icon, _ in
                    guard let icon = icon as? UIImage else { return }
                    if let path = saveImage(icon) {
                        DispatchQueue.main.async {
                            recipe.iconImagePath = path
                        }
                    }
                }
            }
        }
    }
}
fileprivate func saveImage(_ image: UIImage) -> String? {
    // Prefer PNG; fall back to JPEG if needed
    if let pngData = image.pngData() {
        return writeImageData(pngData, fileExtension: "png")
    } else if let jpegData = image.jpegData(compressionQuality: 0.9) {
        return writeImageData(jpegData, fileExtension: "jpg")
    } else {
        print("saveImage: Could not create image data")
        return nil
    }
}

fileprivate func writeImageData(_ data: Data, fileExtension: String) -> String? {
    let fileName = UUID().uuidString + "." + fileExtension
    do {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    } catch {
        print("saveImage: Failed to write image data:", error)
        return nil
    }
}

