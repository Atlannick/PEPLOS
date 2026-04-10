//
//  ClothingCategory.swift
//  PEPLOS
//

import Foundation

struct ClothingCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// Rotating index into `ClothingPlaceholderStyle.palette`; persisted for stable colors per category.
    var pastelStyleIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pastelStyleIndex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pastelStyleIndex = pastelStyleIndex
        self.createdAt = createdAt
    }
}
