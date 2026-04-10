//
//  AppSettingsStore.swift
//  PEPLOS
//

import Combine
import Foundation

enum PeplosSettingsKeys {
    static let userName = "peplos.settings.userName"
    static let gender = "peplos.settings.gender"
    static let temperatureUnit = "peplos.settings.temperatureUnit"
    static let stylePreference = "peplos.settings.stylePreference"
    static let favoriteColors = "peplos.settings.favoriteColors"
    static let hasSeenFirstLaunchGuide = "peplos.settings.hasSeenFirstLaunchGuide"
}

/// High-level style lens for Lucky Look / future stylist (stored locally).
enum PeplosStylePreference: String, CaseIterable, Identifiable, Codable {
    case casual
    case smart
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .smart: return "Smart"
        case .mixed: return "Mixed"
        }
    }
}

enum UserGender: String, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published private(set) var userName: String
    @Published private(set) var gender: UserGender
    @Published private(set) var temperatureUnit: TemperatureUnit
    @Published private(set) var stylePreference: PeplosStylePreference
    @Published private(set) var favoriteFashionColors: [FashionColor]
    @Published private(set) var hasSeenFirstLaunchGuide: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.userName = defaults.string(forKey: PeplosSettingsKeys.userName) ?? ""

        if let raw = defaults.string(forKey: PeplosSettingsKeys.gender),
           let g = UserGender(rawValue: raw) {
            self.gender = g
        } else {
            self.gender = .male
        }

        if let raw = defaults.string(forKey: PeplosSettingsKeys.temperatureUnit),
           let u = TemperatureUnit(rawValue: raw) {
            self.temperatureUnit = u
        } else {
            self.temperatureUnit = .celsius
        }

        if let raw = defaults.string(forKey: PeplosSettingsKeys.stylePreference),
           let p = PeplosStylePreference(rawValue: raw) {
            self.stylePreference = p
        } else {
            self.stylePreference = .mixed
        }

        if let raw = defaults.stringArray(forKey: PeplosSettingsKeys.favoriteColors) {
            let allowed = Set(FashionColor.settingsFavoritePalette.map(\.rawValue))
            let parsed = raw.compactMap { FashionColor(rawValue: $0) }.filter { allowed.contains($0.rawValue) }
            let order = Dictionary(uniqueKeysWithValues: FashionColor.settingsFavoritePalette.enumerated().map { ($0.element, $0.offset) })
            self.favoriteFashionColors = parsed.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
        } else {
            self.favoriteFashionColors = []
        }

        self.hasSeenFirstLaunchGuide = defaults.bool(forKey: PeplosSettingsKeys.hasSeenFirstLaunchGuide)
    }

    func setUserName(_ value: String) {
        userName = value
        defaults.set(value, forKey: PeplosSettingsKeys.userName)
    }

    func setGender(_ value: UserGender) {
        gender = value
        defaults.set(value.rawValue, forKey: PeplosSettingsKeys.gender)
    }

    func setTemperatureUnit(_ value: TemperatureUnit) {
        temperatureUnit = value
        defaults.set(value.rawValue, forKey: PeplosSettingsKeys.temperatureUnit)
    }

    func setStylePreference(_ value: PeplosStylePreference) {
        stylePreference = value
        defaults.set(value.rawValue, forKey: PeplosSettingsKeys.stylePreference)
    }

    func setFavoriteFashionColors(_ colors: [FashionColor]) {
        let allowed = Set(FashionColor.settingsFavoritePalette)
        let filtered = colors.filter { allowed.contains($0) }
        let index = Dictionary(uniqueKeysWithValues: FashionColor.settingsFavoritePalette.enumerated().map { ($0.element, $0.offset) })
        favoriteFashionColors = filtered.sorted { (index[$0] ?? 0) < (index[$1] ?? 0) }
        defaults.set(favoriteFashionColors.map(\.rawValue), forKey: PeplosSettingsKeys.favoriteColors)
    }

    func toggleFavoriteColor(_ color: FashionColor) {
        guard FashionColor.settingsFavoritePalette.contains(color) else { return }
        var next = favoriteFashionColors
        if let i = next.firstIndex(of: color) {
            next.remove(at: i)
        } else {
            next.append(color)
        }
        setFavoriteFashionColors(next)
    }

    func resetToFactoryDefaults() {
        userName = ""
        gender = .male
        temperatureUnit = .celsius
        stylePreference = .mixed
        favoriteFashionColors = []
        hasSeenFirstLaunchGuide = false
        defaults.removeObject(forKey: PeplosSettingsKeys.userName)
        defaults.removeObject(forKey: PeplosSettingsKeys.gender)
        defaults.removeObject(forKey: PeplosSettingsKeys.temperatureUnit)
        defaults.removeObject(forKey: PeplosSettingsKeys.stylePreference)
        defaults.removeObject(forKey: PeplosSettingsKeys.favoriteColors)
        defaults.removeObject(forKey: PeplosSettingsKeys.hasSeenFirstLaunchGuide)
    }

    func replaceFromBackup(settings: BackupSettings) {
        setUserName(settings.userName)
        if let g = UserGender(rawValue: settings.genderRaw) {
            setGender(g)
        }
        if let u = TemperatureUnit(rawValue: settings.temperatureUnitRaw) {
            setTemperatureUnit(u)
        }
        if let p = PeplosStylePreference(rawValue: settings.stylePreferenceRaw) {
            setStylePreference(p)
        }
        let colors = settings.favoriteColorRaws.compactMap(FashionColor.init(rawValue:))
        setFavoriteFashionColors(colors)
    }

    func markFirstLaunchGuideSeen() {
        hasSeenFirstLaunchGuide = true
        defaults.set(true, forKey: PeplosSettingsKeys.hasSeenFirstLaunchGuide)
    }
}
