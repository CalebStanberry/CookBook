//
//  ImageUploadService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/5/26.
//
//  Responsible for resizing, encoding, and uploading cookbook images
//  to the remote sync backend.
//
//  NOTES:
//  - Currently unauthenticated and open endpoint usage.
//  - Fail-fast: throws on encoding failure & HTTP non-success.
//  - Returned URL must be persisted in a DTO or model that performs import/export.
//

import UIKit

enum ImageEncodingError: Error {
    case failedToEncodeJPEG
}

final class ImageUploadService {

    static let shared = ImageUploadService()
    private init() {}

    /// Base worker endpoint for uploads.
    private let baseURL = URL(string: "https://cookbook-sync.recipe-extractor.workers.dev")!

    /// Uploads a UIImage as JPEG to the backend and returns a public image URL.
    ///
    /// - Parameter image: Original full-resolution image.
    /// - Returns: URL of hosted image.
    ///
    /// DETAILS:
    /// - Downscales wide images to ≤1200px width for bandwidth & server-side safety.
    /// - Encodes JPEG @ ~0.75 quality. Good trade-off for cookbook images.
    /// - Throws on encoding or network failure.
    /// - Server is expected to return `{ imageURL: <url> }`.
    @MainActor
    func uploadImage(_ image: UIImage) async throws -> URL {
        // Pre-upload resize to keep worker bandwidth & memory reasonable.
        let resized = image.resized(maxWidth: 1200)

        guard let data = resized.jpegData(compressionQuality: 0.75) else {
            throw ImageEncodingError.failedToEncodeJPEG
        }

        // Build request
        var request = URLRequest(url: baseURL.appendingPathComponent("images"))
        request.httpMethod = "POST"
        request.setValue(AppSecrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        // Perform request
        let (responseData, response) = try await URLSession.shared.data(for: request)

        // Validate HTTP response
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Fail-fast on non-2xx
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "<invalid UTF-8>"
            print("Image upload failed with HTTP \(http.statusCode):", body)
            throw URLError(.badServerResponse)
        }

        // Decode response payload
        struct UploadResponse: Decodable {
            let imageURL: URL
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: responseData)
        print("Image upload response:", uploadResponse.imageURL)

        return uploadResponse.imageURL
    }
}

extension UIImage {

    /// Resizes an image proportionally to ensure it does not exceed a max width.
    /// - Parameter maxWidth: Maximum pixel width allowed.
    /// - Returns: A resized UIImage or the original if already below threshold.
    ///
    /// NOTES:
    /// - Downscaling improves memory usage and network performance.
    /// - Safe for cookbook photography; avoids needless 4k uploads.
    ///
    func resized(maxWidth: CGFloat) -> UIImage {
        let scale = maxWidth / size.width
        guard scale < 1 else { return self }

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
