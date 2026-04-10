//
//  CollectionModel.swift
//  PEPLOS
//

import Foundation

/// A user-created named group for organizing saved outfits.
struct CollectionModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// Join record linking an outfit to a collection (`collection_outfits`).
struct CollectionOutfit: Identifiable, Codable, Hashable {
    let id: UUID
    let collectionId: UUID
    let outfitId: UUID

    init(id: UUID = UUID(), collectionId: UUID, outfitId: UUID) {
        self.id = id
        self.collectionId = collectionId
        self.outfitId = outfitId
    }
}
