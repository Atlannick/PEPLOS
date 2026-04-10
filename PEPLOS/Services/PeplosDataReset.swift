//
//  PeplosDataReset.swift
//  PEPLOS
//

import Foundation

@MainActor
enum PeplosDataReset {
    static func performFactoryReset(
        closet: ClosetStore,
        outfitStore: OutfitStore,
        collectionService: CollectionService,
        luckyLook: LuckyLookManager,
        appSettings: AppSettingsStore
    ) {
        closet.resetToFactoryDefaults()
        outfitStore.resetToFactoryDefaults()
        collectionService.resetToFactoryDefaults()
        luckyLook.clearPersisted()
        TodayPickManager().clearTodayPickPersisted()
        appSettings.resetToFactoryDefaults()
    }
}
