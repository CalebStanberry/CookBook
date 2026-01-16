//
//  CookBook.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/21/25.
//
//  Model representing a cookbook, its recipe groups, and sharing metadata.
//  Designed for use with SwiftData and iOS SwiftUI apps.
//

import Foundation
import SwiftData
import SwiftUI

/// Core `CookBook` model.
/// Represents a cookbook containing recipe groups and sharing metadata.
@Model
final class CookBook: Identifiable {

    /// Unique identifier for the cookbook
    @Attribute(.unique) var id: UUID

    /// Cookbook name
    var name: String

    /// Creation timestamp
    var createdAt: Date

    /// Optional server-side identifier for shared cookbooks
    var sharedID: String?

    /// Version number for sync purposes
    var version: Int

    /// Timestamp of last modification
    var lastModified: Date

    /// Indicates whether this cookbook is shared
    var isShared: Bool

    /// Marks if the cookbook has unsynced local changes
    var isDirty: Bool = false

    /// Recipe groups contained in this cookbook
    /// Cascading deletion; inverse is `RecipeGroup.cookBook`
    @Relationship(deleteRule: .cascade, inverse: \RecipeGroup.cookBook)
    var recipeGroups: [RecipeGroup] = []

    init(
        name: String,
        id: UUID = UUID(),
        createdAt: Date = .now,
        lastModified: Date = .now,
        version: Int = 1,
        isShared: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.version = version
        self.isShared = isShared
    }

    /// Increment the cookbook version and update the lastModified timestamp
    func bumpVersion() {
        version += 1
        lastModified = Date()
    }

    /// Mark the cookbook as needing a sync/push
    func markDirty() {
        isDirty = true
    }

    /// Convert the cookbook and all its recipe groups to a shareable DTO for syncing
    func toShareableDTO() async throws -> ShareableCookBookDTO {
        var groupDTOs: [ShareableRecipeGroupDTO] = []
        groupDTOs.reserveCapacity(recipeGroups.count)
        for group in recipeGroups {
            let dto = try await group.toShareableDTO()
            groupDTOs.append(dto)
        }

        return ShareableCookBookDTO(
            id: id,
            name: name,
            version: version,
            lastModified: lastModified,
            createdAt: createdAt,
            isShared: isShared,
            recipeGroups: groupDTOs
        )
    }

    /// Initialize a `CookBook` from a shared DTO (e.g., downloaded from server)
    /// - Parameters:
    ///   - dto: The shareable DTO representation of a cookbook
    ///   - context: ModelContext to insert new objects
    convenience init(from dto: ShareableCookBookDTO, context: ModelContext) {
        self.init(
            name: dto.name,
            id: dto.id,
            createdAt: dto.createdAt
        )

        self.isShared = true
        self.version = dto.version
        self.lastModified = dto.lastModified

        // Map remote recipe groups to local RecipeGroup objects
        self.recipeGroups = dto.recipeGroups.map {
            CookBookImportService.importRecipeGroup($0, context: context)
        }
    }
     
     func pushIfShared() {
         guard isShared else { return }
         bumpVersion()
         isDirty = false
         Task {
             do {
                 try await CookBookSyncService.shared.prepareImagesForSharing(self)
                 let dto = try await self.toShareableDTO()
                 try await CookBookSyncService.shared.push(dto)
             } catch {
                 print("Failed to push CookBook:", error)
                 isDirty = true // retry next time
             }
         }
     }
}

extension Array where Element == RecipeGroup {
    /// Return the 3 newest recipes across all recipe groups
    var newestRecipes: [Recipe] {
        self
            .flatMap(\.recipes)            // Flatten all recipes
            .sorted { $0.createdAt > $1.createdAt } // Sort by newest first
            .prefix(3)                     // Take the top 3
            .map { $0 }                     // Convert SubSequence to Array
    }
}
