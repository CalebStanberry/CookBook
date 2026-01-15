import Foundation
import LinkPresentation
import UIKit
import SwiftData

@MainActor
final class PreviewService {

    static let shared = PreviewService()
    private init() {}
    
    // Track active fetch tasks to ensure they can be cancelled
    private var activeFetches: [UUID: Task<Void, Never>] = [:]

    func fetchPreview(for recipe: Recipe, using modelContext: ModelContext) {
        // Don't fetch if we already have valid data from sync
        if recipe.title != "No Title" && !recipe.siteName.isEmpty {
            print("Skipping preview fetch - recipe already has metadata")
            return
        }
        
        // Cancel any existing fetch for this recipe
        activeFetches[recipe.id]?.cancel()
        
        guard let url = URL(string: recipe.url) else {
            print("Invalid URL:", recipe.url)
            recipe.previewFailed = true
            recipe.isFetchingPreview = false
            try? modelContext.save()
            return
        }

        // Start loading
        recipe.isFetchingPreview = true
        try? modelContext.save()
        
        print("Starting preview fetch for:", url.absoluteString)

        let fetchTask = Task {
            var completed = false
            
            // Create timeout task
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(15))
                if !completed && !Task.isCancelled {
                    print("TIMEOUT after 15s for:", url.absoluteString)
                    await MainActor.run {
                        recipe.previewFailed = true
                        recipe.isFetchingPreview = false
                        try? modelContext.save()
                    }
                    completed = true
                }
            }
            
            let provider = LPMetadataProvider()
            provider.timeout = 10.0
            
            // Wrap in a continuation to make it async/await
            let metadata = await withCheckedContinuation { continuation in
                provider.startFetchingMetadata(for: url) { metadata, error in
                    if !completed {
                        print("Metadata fetch completed")
                        continuation.resume(returning: metadata)
                    }
                }
            }
            
            // Cancel timeout since we got a response
            timeoutTask.cancel()
            
            guard !Task.isCancelled, !completed else {
                print("Task was cancelled")
                return
            }
            
            completed = true
            
            guard let metadata = metadata else {
                print("No metadata returned")
                recipe.previewFailed = true
                recipe.isFetchingPreview = false
                try? modelContext.save()
                return
            }

            print("Got metadata:", metadata.title ?? "no title")
            recipe.previewFailed = false
            recipe.title = metadata.title ?? "Unknown Title"
            recipe.siteName = url.host?.replacingOccurrences(of: "www.", with: "") ?? "Unknown Site"
            try? modelContext.save()

            // Track image loading
            var pendingImages = 0
            
            if metadata.imageProvider != nil { pendingImages += 1 }
            if metadata.iconProvider != nil { pendingImages += 1 }
            
            // If no images, we're done
            if pendingImages == 0 {
                print("No images to load, fetch complete")
                recipe.isFetchingPreview = false
                try? modelContext.save()
                activeFetches[recipe.id] = nil
                return
            }
            
            print("Loading \(pendingImages) image(s)")
            
            // Image loading timeout
            let imageTimeoutTask = Task {
                try? await Task.sleep(for: .seconds(10))
                if pendingImages > 0 && !Task.isCancelled {
                    print("Image loading timeout")
                    await MainActor.run {
                        recipe.isFetchingPreview = false
                        try? modelContext.save()
                    }
                }
            }
            
            func imageCompleted() {
                Task { @MainActor in
                    pendingImages -= 1
                    print("Image completed, \(pendingImages) remaining")
                    if pendingImages == 0 {
                        imageTimeoutTask.cancel()
                        recipe.isFetchingPreview = false
                        try? modelContext.save()
                        activeFetches[recipe.id] = nil
                        print("All images loaded, fetch complete")
                    }
                }
            }

            // Handle hero image
            if let imageProvider = metadata.imageProvider {
                imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    defer { imageCompleted() }
                    
                    guard let image = image as? UIImage,
                          let fileName = saveImage(image) else {
                        print("Failed to save hero image")
                        return
                    }

                    Task { @MainActor in
                        recipe.heroImageFileName = fileName
                        print("Hero image saved:", fileName)
                        try? modelContext.save()
                    }
                }
            }

            // Handle icon
            if let iconProvider = metadata.iconProvider {
                iconProvider.loadObject(ofClass: UIImage.self) { icon, _ in
                    defer { imageCompleted() }
                    
                    guard let icon = icon as? UIImage,
                          let fileName = saveImage(icon) else {
                        print("❌ Failed to save icon")
                        return
                    }

                    Task { @MainActor in
                        recipe.iconImageFileName = fileName
                        print("Icon saved:", fileName)
                        try? modelContext.save()
                    }
                }
            }
        }
        
        activeFetches[recipe.id] = fetchTask
    }
}

internal func savePath(_ path: String) -> String? {
    // Check if file exists first
    guard FileManager.default.fileExists(atPath: path) else {
        print("Error: File does not exist at path: \(path)")
        return nil
    }
    
    // Try to load the image
    guard let image = UIImage(contentsOfFile: path) else {
        print("Error: Could not decode image from path: \(path)")
        return nil
    }
    
    // Save and return the new filename
    return saveImage(image)
}

internal func saveImage(_ image: UIImage) -> String? {
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
        
        // Return only the filename, not the full path
        return fileName
    } catch {
        print("saveImage: Failed to write image data:", error)
        return nil
    }
}
