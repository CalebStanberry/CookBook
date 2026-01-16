//
//  RootView.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/5/26.
//

import SwiftUI
import SwiftData

/// Entry point for the primary UI layer of the CookBook app.
///
/// Responsible for:
/// - Rendering the cookbook list
/// - Handling URL-based cookbook import requests
struct RootView: View {

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        CookBookListView()
            .onOpenURL { url in
                handleIncomingURL(url)
            }
    }

    /// Handles cookbook imports triggered by incoming URLs.
    ///
    /// Expected URL format:
    ///   `cookbook://import/<UUID>`
    ///
    /// Performs:
    /// - URL validation
    /// - UUID extraction
    /// - Network fetch via `CookBookSyncService`
    /// - Data model import via `CookBookImportService`
    private func handleIncomingURL(_ url: URL) {
        guard
            url.scheme == "cookbook",
            url.host == "import",
            let id = UUID(uuidString: url.lastPathComponent)
        else {
            print("Invalid URL:", url)
            return
        }

        print("Import requested via URL:", id)

        Task {
            do {
                let dto = try await CookBookSyncService.shared.fetch(sharedID: id)

                await MainActor.run {
                    CookBookImportService.importCookBook(dto, context: modelContext)

                    let count = (try? modelContext.fetch(FetchDescriptor<CookBook>()).count) ?? -1
                    print("CookBooks after import:", count)
                }

            } catch {
                print("Failed to import cookbook:", error)
            }
        }
    }
}
