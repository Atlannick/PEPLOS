//
//  BackupService.swift
//  PEPLOS
//

import Foundation

@MainActor
enum BackupService {
    private enum Keys {
        static let lastExportAt = "peplos.backup.lastExportAt"
    }

    private static var formatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    private static var exportFileNameDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func makeExportFile(
        closet: ClosetStore,
        outfitStore: OutfitStore,
        collectionService: CollectionService,
        appSettings: AppSettingsStore
    ) throws -> URL {
        let imageFiles = collectImageFiles(from: closet.items)
        let envelope = BackupEnvelope(
            appIdentifier: BackupFormat.appIdentifier,
            appName: BackupFormat.appName,
            backupFormatVersion: BackupFormat.version,
            exportedAt: Date(),
            appVersion: PeplosAppVersion.marketingAndBuild,
            datasets: BackupDatasets(
                closetCategories: closet.categories,
                closetItems: closet.items,
                imageFiles: imageFiles,
                outfits: outfitStore.outfits,
                collections: collectionService.collections,
                collectionOutfits: collectionService.collectionOutfits,
                settings: BackupSettings(
                    userName: appSettings.userName,
                    genderRaw: appSettings.gender.rawValue,
                    temperatureUnitRaw: appSettings.temperatureUnit.rawValue,
                    stylePreferenceRaw: appSettings.stylePreference.rawValue,
                    favoriteColorRaws: appSettings.favoriteFashionColors.map(\.rawValue)
                )
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)

        let dateString = exportFileNameDateFormatter.string(from: Date())
        let fileName = "peplos-backup-\(dateString).\(BackupFormat.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func markExportCompleted(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: Keys.lastExportAt)
    }

    static func lastExportText() -> String {
        formatted(UserDefaults.standard.object(forKey: Keys.lastExportAt) as? Date)
    }

    static func importBackup(
        from fileURL: URL,
        closet: ClosetStore,
        outfitStore: OutfitStore,
        collectionService: CollectionService,
        appSettings: AppSettingsStore
    ) throws {
        let envelope = try BackupValidator.validateAndDecodeBackup(from: fileURL)
        try createSafetySnapshot(
            closet: closet,
            outfitStore: outfitStore,
            collectionService: collectionService,
            appSettings: appSettings
        )
        if let imageFiles = envelope.datasets.imageFiles {
            try restoreImageFiles(imageFiles)
        }
        closet.replaceFromBackup(
            categories: envelope.datasets.closetCategories,
            items: envelope.datasets.closetItems
        )
        outfitStore.replaceFromBackup(outfits: envelope.datasets.outfits)
        collectionService.replaceFromBackup(
            collections: envelope.datasets.collections,
            collectionOutfits: envelope.datasets.collectionOutfits
        )
        appSettings.replaceFromBackup(settings: envelope.datasets.settings)
    }

    private static func createSafetySnapshot(
        closet: ClosetStore,
        outfitStore: OutfitStore,
        collectionService: CollectionService,
        appSettings: AppSettingsStore
    ) throws {
        let current = BackupEnvelope(
            appIdentifier: BackupFormat.appIdentifier,
            appName: BackupFormat.appName,
            backupFormatVersion: BackupFormat.version,
            exportedAt: Date(),
            appVersion: PeplosAppVersion.marketingAndBuild,
            datasets: BackupDatasets(
                closetCategories: closet.categories,
                closetItems: closet.items,
                imageFiles: collectImageFiles(from: closet.items),
                outfits: outfitStore.outfits,
                collections: collectionService.collections,
                collectionOutfits: collectionService.collectionOutfits,
                settings: BackupSettings(
                    userName: appSettings.userName,
                    genderRaw: appSettings.gender.rawValue,
                    temperatureUnitRaw: appSettings.temperatureUnit.rawValue,
                    stylePreferenceRaw: appSettings.stylePreference.rawValue,
                    favoriteColorRaws: appSettings.favoriteFashionColors.map(\.rawValue)
                )
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(current)

        let dir = DurableStore.backupEligibleDirectoryURL.appendingPathComponent("SafetySnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "pre-import-\(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).\(BackupFormat.fileExtension)"
        let url = dir.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func formatted(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private static func collectImageFiles(from items: [ClothingItem]) -> [BackupImageFile] {
        let fileNames = Set(items.flatMap { [$0.imageFileName, $0.thumbnailFileName, $0.originalImageFileName] }.compactMap { $0 })
        var payload: [BackupImageFile] = []
        payload.reserveCapacity(fileNames.count)
        for name in fileNames {
            let url = ClothingImageStorage.fileURL(fileName: name)
            guard let data = try? Data(contentsOf: url) else { continue }
            payload.append(BackupImageFile(fileName: name, data: data))
        }
        return payload.sorted { $0.fileName < $1.fileName }
    }

    private static func restoreImageFiles(_ files: [BackupImageFile]) throws {
        try ClothingImageStorage.ensureDirectoryExists()
        for file in files {
            let url = ClothingImageStorage.fileURL(fileName: file.fileName)
            try file.data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }
}
