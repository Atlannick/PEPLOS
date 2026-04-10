//
//  SavedOutfit.swift
//  PEPLOS
//

import Foundation

struct SavedOutfit: Identifiable, Hashable {
    let id: UUID
    var name: String
    var itemCount: Int
    var itemIds: [UUID]

    init(id: UUID = UUID(), name: String, itemIds: [UUID]) {
        self.id = id
        self.name = name
        self.itemIds = itemIds
        self.itemCount = itemIds.count
    }
}

extension SavedOutfit: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, itemCount, itemIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let decodedIds = try c.decodeIfPresent([UUID].self, forKey: .itemIds) ?? []
        let storedCount = try c.decode(Int.self, forKey: .itemCount)
        itemIds = decodedIds
        itemCount = decodedIds.isEmpty ? storedCount : decodedIds.count
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(itemIds, forKey: .itemIds)
        try c.encode(itemIds.count, forKey: .itemCount)
    }
}

extension SavedOutfit {
    static let previewHadi = SavedOutfit(name: "hadi", itemIds: [])
}
