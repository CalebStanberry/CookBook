//
//  CookBookSyncService.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/4/26.
//
//  Responsibilities:
//  - Push/pull shared CookBooks via remote Worker
//  - Handle image upload workflow
//  - Maintain periodic sync
//  - Produce deep link share URLs
//

import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
final class CookBookSyncService: ObservableObject {
    
    static let shared = CookBookSyncService()
    private let baseURL = URL(string: "https://cookbook-sync.recipe-extractor.workers.dev")!
    private var autoSyncTask: Task<Void, Never>?
    @Published var lastSync: Date?
    
    private init() {}
}

extension CookBookSyncService {
    
    /// Starts background sync every 30 seconds. Cancels prior tasks first.
    func startAutoSync(context: ModelContext) {
        stopAutoSync()
        
        autoSyncTask = Task {
            while !Task.isCancelled {
                await syncAllCookBooks(context: context)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
    
    /// Cancels sync task. (Replaces unused Timer-based approach)
    func stopAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }
    
    /// Full push of a single CookBook (used for explicit edits)
    func sync(_ cookBook: CookBook, context: ModelContext) async {
        guard cookBook.isShared else { return }

        do {
            cookBook.bumpVersion()
            cookBook.isDirty = false
            
            try await prepareImagesForSharing(cookBook)
            let dto = try await cookBook.toShareableDTO()
            try await push(dto)
        } catch {
            cookBook.isDirty = true
            print("Sync failed:", error)
        }
    }
}

// Multi-CookBook Sync
extension CookBookSyncService {
    
    /// Main reconciliation pass across all shared CookBooks
    func syncAllCookBooks(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<CookBook>()
            let localCookBooks = try context.fetch(descriptor)
            
            for book in localCookBooks where book.isShared {
                
                // Upload images before version comparison
                try await prepareImagesForSharing(book)
                
                print("Syncing:", book.id)
                
                // Local snapshot
                let localDTO = try await book.toShareableDTO()
                
                do {
                    // Attempt remote fetch
                    let remoteDTO = try await fetch(sharedID: book.id)
                    
                    if remoteDTO.version > localDTO.version {
                        // Remote wins → merge/import
                        print("Remote newer → import")
                        CookBookImportService.importCookBook(remoteDTO, context: context)
                        
                    } else if localDTO.version > remoteDTO.version {
                        // Local wins → push
                        print("Local newer → push")
                        try await push(localDTO)
                        
                    } else {
                        // Versions align → nothing to do
                        print("Versions equal → no-op")
                    }
                    
                } catch {
                    // Missing remote entry → bootstrap push
                    try? await push(localDTO)
                }
            }
            
            lastSync = Date()
            
        } catch {
            print("Global sync failed:", error)
        }
    }
}

// Remote Fetch / Push / Delete
extension CookBookSyncService {
    
    /// Fetches remote CookBook via GET
    func fetch(sharedID: UUID) async throws -> ShareableCookBookDTO {
        let url = baseURL.appendingPathComponent("cookbooks/\(sharedID.uuidString)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Fetch \(sharedID) status:", http.statusCode)
        print("payload:", String(data: data, encoding: .utf8) ?? "<unreadable>")
        
        return try JSONDecoder().decode(ShareableCookBookDTO.self, from: data)
    }
    
    /// Pushes DTO via POST for upsert behavior
    func push(_ dto: ShareableCookBookDTO) async throws {
        let url = baseURL.appendingPathComponent("cookbooks/\(dto.id.uuidString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AppSecrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            print("Push status:", http.statusCode)
            print("response:", String(data: data, encoding: .utf8) ?? "<no body>")
            
            guard (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }
    }
    
    /// Deletes remote shared CookBook
    func deleteSharedCookBook(_ book: CookBook) async throws {
        let url = baseURL.appendingPathComponent("cookbooks/\(book.id.uuidString)")
        
        var request = URLRequest(url: url)
        request.setValue(AppSecrets.appToken, forHTTPHeaderField: "X-App-Token")
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// Image Upload Pipeline
extension CookBookSyncService {
    
    /// Uploads images for recipes that require it
    func prepareImagesForSharing(_ cookBook: CookBook) async throws {
        for group in cookBook.recipeGroups {
            for recipe in group.recipes where recipe.needsImageUpload {
                
                guard let path = recipe.heroImageFullPath,
                      let image = UIImage(contentsOfFile: path) else { continue }
                
                print("Preparing image upload for:", recipe.title)
                
                do {
                    let remoteURL = try await ImageUploadService.shared.uploadImage(image)
                    recipe.needsImageUpload = false
                    recipe.heroImageRemoteURL = remoteURL.absoluteString
                    
                } catch {
                    print("Image upload failed:", recipe.title)
                    throw error
                }
            }
        }
    }
}

// Share Link Generation
extension CookBookSyncService {
    
    /// Generates cookbook:// import URL for handoff via ShareSheet
    func shareURL(for cookBook: CookBook) -> URL {
        URL(string: "cookbook://import/\(cookBook.id.uuidString)")!
    }
}

/*
 Potential improvements:
 - Move conflict resolver to SyncCoordinator
 - Remove local versioning from model; base on lamport or CRDT
 - Batch remote requests for N cookbooks instead of 1:1 HTTP calls
 - Extract image pipeline to ImageSyncService
 - Support backoff + retry for push failures
*/
