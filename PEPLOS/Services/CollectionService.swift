//
//  CollectionService.swift
//  PEPLOS
//

import Combine
import Foundation

@MainActor
final class CollectionService: ObservableObject {
    @Published private(set) var collections: [CollectionModel] = []
    /// Persisted links (`collection_outfits`): one row per outfit–collection pair.
    @Published private(set) var collectionOutfits: [CollectionOutfit] = []

    private let collectionsKey = "peplos.collections"
    private let linksKey = "peplos.collection_outfits"
    private let collectionsFileName = "collections.v1.json"
    private let linksFileName = "collection_outfits.v1.json"

    init() {
        load()
    }

    /// Adds a collection and returns it.
    @discardableResult
    func addCollection(named name: String) -> CollectionModel? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let model = CollectionModel(name: trimmed)
        collections.append(model)
        collections.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
        return model
    }

    /// Ensures a link exists in `collection_outfits` for this outfit and collection.
    /// The same outfit may appear in many collections; only duplicate pairs are skipped.
    func saveOutfit(_ outfitId: UUID, toCollectionId collectionId: UUID) {
        let exists = collectionOutfits.contains { $0.collectionId == collectionId && $0.outfitId == outfitId }
        guard !exists else { return }
        collectionOutfits.append(CollectionOutfit(collectionId: collectionId, outfitId: outfitId))
        save()
    }

    func outfitIds(inCollectionId collectionId: UUID) -> [UUID] {
        collectionOutfits
            .filter { $0.collectionId == collectionId }
            .map(\.outfitId)
    }

    /// Outfits still in the wardrobe list, in link order (newest appended last in `collectionOutfits`).
    func savedOutfits(inCollectionId collectionId: UUID, from outfitStore: OutfitStore) -> [SavedOutfit] {
        let idOrder = outfitIds(inCollectionId: collectionId)
        let byId = Dictionary(uniqueKeysWithValues: outfitStore.outfits.map { ($0.id, $0) })
        return idOrder.compactMap { byId[$0] }
    }

    func removeOutfitFromAllCollections(_ outfitId: UUID) {
        let before = collectionOutfits.count
        collectionOutfits.removeAll { $0.outfitId == outfitId }
        guard collectionOutfits.count != before else { return }
        save()
    }

    /// Removes only this outfit–collection link; the saved outfit stays in the wardrobe.
    func removeOutfit(_ outfitId: UUID, fromCollectionId collectionId: UUID) {
        let before = collectionOutfits.count
        collectionOutfits.removeAll { $0.collectionId == collectionId && $0.outfitId == outfitId }
        guard collectionOutfits.count != before else { return }
        save()
    }

    /// Removes the collection and all outfit links for it (outfits themselves are unchanged).
    func deleteCollection(id: UUID) {
        let hadCollection = collections.contains { $0.id == id }
        guard hadCollection else { return }
        collections.removeAll { $0.id == id }
        collectionOutfits.removeAll { $0.collectionId == id }
        save()
    }

    func resetToFactoryDefaults() {
        collections = []
        collectionOutfits = []
        DurableStore.clear(fileName: collectionsFileName, defaultsKey: collectionsKey)
        DurableStore.clear(fileName: linksFileName, defaultsKey: linksKey)
    }

    func replaceFromBackup(collections: [CollectionModel], collectionOutfits: [CollectionOutfit]) {
        self.collections = collections.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.collectionOutfits = collectionOutfits
        save()
    }

    private func load() {
        if let decoded = DurableStore.load([CollectionModel].self, fileName: collectionsFileName, defaultsKey: collectionsKey) {
            collections = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            collections = []
        }

        if let decoded = DurableStore.load([CollectionOutfit].self, fileName: linksFileName, defaultsKey: linksKey) {
            collectionOutfits = decoded
        } else {
            collectionOutfits = []
        }
    }

    private func save() {
        DurableStore.save(collections, fileName: collectionsFileName, defaultsKey: collectionsKey)
        DurableStore.save(collectionOutfits, fileName: linksFileName, defaultsKey: linksKey)
    }
}
