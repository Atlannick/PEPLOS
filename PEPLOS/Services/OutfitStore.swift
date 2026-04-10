//
//  OutfitStore.swift
//  PEPLOS
//

import Combine
import Foundation

@MainActor
final class OutfitStore: ObservableObject {
    @Published private(set) var outfits: [SavedOutfit] = []

    private let saveKey = "peplos.outfits"
    private let fileName = "outfits.v1.json"

    init() {
        load()
    }

    func addOutfit(_ outfit: SavedOutfit) {
        outfits.append(outfit)
        save()
    }

    func removeOutfit(id: UUID) {
        outfits.removeAll { $0.id == id }
        save()
    }

    func updateOutfit(_ outfit: SavedOutfit) {
        guard let idx = outfits.firstIndex(where: { $0.id == outfit.id }) else { return }
        outfits[idx] = outfit
        save()
    }

    func resetToFactoryDefaults() {
        outfits = []
        DurableStore.clear(fileName: fileName, defaultsKey: saveKey)
    }

    func replaceFromBackup(outfits: [SavedOutfit]) {
        self.outfits = outfits
        save()
    }

    private func load() {
        guard let decoded = DurableStore.load([SavedOutfit].self, fileName: fileName, defaultsKey: saveKey) else {
            outfits = []
            return
        }
        outfits = decoded
    }

    private func save() {
        DurableStore.save(outfits, fileName: fileName, defaultsKey: saveKey)
    }
}
