//
//  DurableStore.swift
//  PEPLOS
//
//  JSON persistence with a backup copy for recovery.
//

import Foundation

enum DurableStore {
    private static let folderName = "Persistence"

    private static var directoryURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func fileURL(_ fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    private static func backupURL(_ fileName: String) -> URL {
        directoryURL.appendingPathComponent("\(fileName).bak")
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    /// `Application Support` is backup-eligible by default on iOS.
    /// Keeping core files here allows normal encrypted iPhone/iCloud device backup + restore.
    static var backupEligibleDirectoryURL: URL {
        directoryURL
    }

    static func save<T: Codable>(_ payload: T, fileName: String, defaultsKey: String? = nil) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        do {
            try ensureDirectoryExists()
            let main = fileURL(fileName)
            let bak = backupURL(fileName)
            try data.write(to: main, options: [.atomic, .completeFileProtection])
            try data.write(to: bak, options: [.atomic, .completeFileProtection])
            if let defaultsKey {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        } catch {
            if let defaultsKey {
                // Keep legacy persistence path alive even if file writes fail.
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
    }

    static func load<T: Codable>(_ type: T.Type, fileName: String, defaultsKey: String? = nil) -> T? {
        let main = fileURL(fileName)
        let bak = backupURL(fileName)
        let decoder = JSONDecoder()

        if let data = try? Data(contentsOf: main),
           let decoded = try? decoder.decode(type, from: data) {
            return decoded
        }
        if let data = try? Data(contentsOf: bak),
           let decoded = try? decoder.decode(type, from: data) {
            return decoded
        }
        if let defaultsKey,
           let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? decoder.decode(type, from: data) {
            return decoded
        }
        return nil
    }

    static func clear(fileName: String, defaultsKey: String? = nil) {
        let fm = FileManager.default
        try? fm.removeItem(at: fileURL(fileName))
        try? fm.removeItem(at: backupURL(fileName))
        if let defaultsKey {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    /// Validates persistence file(s) and repairs main file from backup/legacy mirror if possible.
    static func validateAndRepair<T: Codable>(
        _ type: T.Type,
        fileName: String,
        defaultsKey: String? = nil
    ) -> Bool {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        let main = fileURL(fileName)
        let bak = backupURL(fileName)
        let hasMain = fm.fileExists(atPath: main.path)
        let hasBak = fm.fileExists(atPath: bak.path)
        let hasDefaults = defaultsKey.flatMap { UserDefaults.standard.data(forKey: $0) } != nil

        // No persisted data yet is valid (e.g. first launch, empty optional datasets).
        if !hasMain && !hasBak && !hasDefaults {
            return true
        }

        if let data = try? Data(contentsOf: main),
           (try? decoder.decode(type, from: data)) != nil {
            return true
        }
        if let data = try? Data(contentsOf: bak),
           let decoded = try? decoder.decode(type, from: data) {
            save(decoded, fileName: fileName, defaultsKey: defaultsKey)
            return true
        }
        if let defaultsKey,
           let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? decoder.decode(type, from: data) {
            save(decoded, fileName: fileName, defaultsKey: defaultsKey)
            return true
        }
        return false
    }
}
