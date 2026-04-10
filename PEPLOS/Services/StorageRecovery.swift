//
//  StorageRecovery.swift
//  PEPLOS
//

import Foundation

enum StorageRecovery {
    /// Validates core persisted datasets at startup.
    /// If a main file is corrupted, attempts repair from `.bak` (or mirrored defaults).
    static func validateCorePersistenceAtLaunch() -> [String] {
        var failures: [String] = []

        if !DurableStore.validateAndRepair(ClosetSnapshot.self, fileName: "closet.v2.json", defaultsKey: "peplos.closet.persisted.v2") {
            failures.append("Closet data could not be recovered.")
        }
        if !DurableStore.validateAndRepair([SavedOutfit].self, fileName: "outfits.v1.json", defaultsKey: "peplos.outfits") {
            failures.append("Outfit data could not be recovered.")
        }
        if !DurableStore.validateAndRepair([CollectionModel].self, fileName: "collections.v1.json", defaultsKey: "peplos.collections") {
            failures.append("Collection data could not be recovered.")
        }
        if !DurableStore.validateAndRepair([CollectionOutfit].self, fileName: "collection_outfits.v1.json", defaultsKey: "peplos.collection_outfits") {
            failures.append("Collection links could not be recovered.")
        }
        return failures
    }
}

struct ClosetSnapshot: Codable {
    var categories: [ClothingCategory]
    var items: [ClothingItem]
}
