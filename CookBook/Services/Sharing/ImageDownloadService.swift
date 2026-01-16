//
//  ImageDownloadService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/5/26.
//

import UIKit

/// Responsible for downloading remote images and persisting them to
/// the app's user document directory. Used primarily during inbound
/// sync / import operations for shared cookbooks.
///
/// Notes:
///   - This service is intentionally “write-only” and does not attempt
///     caching, duplicate detection, or hashing.
///   - All returned paths are filesystem-local absolute paths.
///   - Caller is responsible for storing the filename/path on the model.
final class ImageDownloadService {
    static let shared = ImageDownloadService()

    /// Downloads a remote image and persists it as a `.jpg` file.
    ///
    /// - Parameter url: Fully qualified remote image URL
    /// - Returns: `String` absolute path to stored image on disk
    ///
    /// NOTE: This function performs both I/O + decode and should not
    /// be called from the main thread during UI interactions. Callers
    /// currently run this from Task context during inbound sync.
    ///
    /// Storage:
    ///   Writes into `Documents/` which is backed up unless excluded.
    ///
    /// Disk Format:
    ///   Uses JPEG (0.9) for reasonable size/perf tradeoff.
    @discardableResult
    func downloadAndSaveImage(from url: URL) async throws -> String {
        // Network fetch (async, resume on background)
        let (data, _) = try await URLSession.shared.data(from: url)

        // Validate decodeability (prevents corrupt writes)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        // File naming strategy:
        //   UUID ensures uniqueness, avoids conflicts.
        //   Extension fixed to .jpg (compression step below).
        let filename = UUID().uuidString + ".jpg"

        // Documents/ is currently correct for persistent user-generated data
        // Though remote sync images may be re-downloadable, so Caches/ may be better long-term.
        let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        // Compression note:
        //   0.9 yields high quality
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            // If JPEG conversion fails, report appropriately.
            // Using cannotCreateFile since this maps closest semantically.
            throw URLError(.cannotCreateFile)
        }

        // Disk write — currently synchronous
        try jpeg.write(to: path)

        // Returning absolute path (not fileName)
        return path.path
    }
}
