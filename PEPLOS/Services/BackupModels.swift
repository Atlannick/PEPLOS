//
//  BackupModels.swift
//  PEPLOS
//

import Foundation

enum BackupFormat {
    static let appIdentifier = "peplos.local.backup"
    static let appName = "PEPLOS"
    static let version = 1
    static let fileExtension = "peplosbackup"
}

struct BackupEnvelope: Codable {
    var appIdentifier: String
    var appName: String
    var backupFormatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var datasets: BackupDatasets
}

struct BackupDatasets: Codable {
    var closetCategories: [ClothingCategory]
    var closetItems: [ClothingItem]
    /// Optional file payloads for `ClothingImageStorage` (introduced after v1 backups).
    var imageFiles: [BackupImageFile]?
    var outfits: [SavedOutfit]
    var collections: [CollectionModel]
    var collectionOutfits: [CollectionOutfit]
    var settings: BackupSettings
}

struct BackupImageFile: Codable, Hashable {
    var fileName: String
    var data: Data
}

struct BackupSettings: Codable {
    var userName: String
    var genderRaw: String
    var temperatureUnitRaw: String
    var stylePreferenceRaw: String
    var favoriteColorRaws: [String]
}

enum BackupValidationError: LocalizedError {
    case invalidExtension
    case invalidData
    case wrongApp
    case unsupportedVersion
    case missingDatasets

    var errorDescription: String? {
        switch self {
        case .invalidExtension:
            return "This file is not a Peplos backup (.peplosbackup)."
        case .invalidData:
            return "The selected backup file could not be read."
        case .wrongApp:
            return "This backup does not belong to Peplos."
        case .unsupportedVersion:
            return "This backup version is not supported by this app version."
        case .missingDatasets:
            return "The backup is missing required data."
        }
    }
}
