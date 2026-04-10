//
//  BackupValidator.swift
//  PEPLOS
//

import Foundation

enum BackupValidator {
    static func validateAndDecodeBackup(from fileURL: URL) throws -> BackupEnvelope {
        guard fileURL.pathExtension.lowercased() == BackupFormat.fileExtension else {
            throw BackupValidationError.invalidExtension
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            throw BackupValidationError.invalidData
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(BackupEnvelope.self, from: data) else {
            throw BackupValidationError.invalidData
        }
        guard envelope.appIdentifier == BackupFormat.appIdentifier else {
            throw BackupValidationError.wrongApp
        }
        guard envelope.backupFormatVersion <= BackupFormat.version else {
            throw BackupValidationError.unsupportedVersion
        }
        guard envelope.appName == BackupFormat.appName else {
            throw BackupValidationError.missingDatasets
        }
        return envelope
    }
}
