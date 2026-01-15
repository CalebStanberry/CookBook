//
//  HTMLFetcher.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/22/25.
//

import Foundation

/// Simple utility to fetch the raw HTML content of a webpage.
/// Used in RecipeExtractionService to retrieve recipe pages for parsing.
struct HTMLFetcher {

    /// Fetches the HTML content from the given URL asynchronously.
    /// - Parameter url: The URL of the webpage to fetch.
    /// - Returns: A `String` containing the HTML content of the page.
    static func fetch(url: URL) async throws -> String {
        // Perform a network request to get raw data
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Convert the data to a UTF-8 string
        return String(decoding: data, as: UTF8.self)
    }
}
