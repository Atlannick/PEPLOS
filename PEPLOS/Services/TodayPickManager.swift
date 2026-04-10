//
//  TodayPickManager.swift
//  PEPLOS
//

import Foundation

// MARK: - Weather band (°C)

enum WeatherComfortBand: Equatable {
    case cold
    case mild
    case warm
    case hot

    init(celsius: Double) {
        switch celsius {
        case ..<10: self = .cold
        case 10..<18: self = .mild
        case 18..<26: self = .warm
        default: self = .hot
        }
    }

    static func from(weatherCelsius: Double?) -> WeatherComfortBand? {
        guard let c = weatherCelsius else { return nil }
        return WeatherComfortBand(celsius: c)
    }
}

// MARK: - Result

struct TodayPickResult: Equatable {
    let outfit: SavedOutfit?
    let explanation: String
}

/// User-triggered daily look: persists only after the user requests a recommendation. Resets at local midnight.
struct TodayPickManager {
    private let defaults: UserDefaults

    private enum Keys {
        static let outfitId = "peplos.todaysLook.request.outfitId"
        static let dayStart = "peplos.todaysLook.request.dayStart"
        static let explanation = "peplos.todaysLook.request.explanation"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Today's locked look after the user tapped "Get today's look", if any.
    func storedLookForToday(outfits: [SavedOutfit], now: Date = .init()) -> TodayPickResult? {
        guard !outfits.isEmpty else {
            clearPersistedLook()
            return nil
        }

        let todayStart = Self.startOfDayTimestamp(for: now)
        guard defaults.object(forKey: Keys.dayStart) != nil else { return nil }

        let storedDay = defaults.double(forKey: Keys.dayStart)
        guard storedDay == todayStart,
              let idString = defaults.string(forKey: Keys.outfitId),
              let id = UUID(uuidString: idString),
              let outfit = outfits.first(where: { $0.id == id }) else {
            if storedDay != todayStart {
                clearPersistedLook()
            }
            return nil
        }

        let line = defaults.string(forKey: Keys.explanation) ?? Self.explanationSentence(weatherCelsius: nil)
        return TodayPickResult(outfit: outfit, explanation: line)
    }

    /// Picks one outfit from the closet using current weather rules. Does not persist.
    func computeRecommendation(
        outfits: [SavedOutfit],
        weatherCelsius: Double?,
        categoryNameForItemId: (UUID) -> String?
    ) -> TodayPickResult? {
        guard !outfits.isEmpty else { return nil }

        let band = WeatherComfortBand.from(weatherCelsius: weatherCelsius)
        let pool = Self.filteredOutfits(outfits, band: band, categoryNameForItemId: categoryNameForItemId)
        guard let pick = pool.randomElement() else { return nil }

        let explanation = Self.explanationSentence(weatherCelsius: weatherCelsius)
        return TodayPickResult(outfit: pick, explanation: explanation)
    }

    /// Call when the user requests today's look (before the reveal delay).
    func persistTodaysRecommendation(_ result: TodayPickResult, now: Date = .init()) {
        guard let outfit = result.outfit else { return }
        let todayStart = Self.startOfDayTimestamp(for: now)
        defaults.set(outfit.id.uuidString, forKey: Keys.outfitId)
        defaults.set(todayStart, forKey: Keys.dayStart)
        defaults.set(result.explanation, forKey: Keys.explanation)
    }

    // MARK: - Explanation

    static func explanationSentence(weatherCelsius: Double?) -> String {
        guard let c = weatherCelsius else {
            return "Today's randomly selected outfit."
        }
        switch WeatherComfortBand(celsius: c) {
        case .cold:
            return "Picked for today's cold weather."
        case .mild:
            return "A comfortable look for today."
        case .warm:
            return "Light outfit for today's warm weather."
        case .hot:
            return "Perfect for the heat today."
        }
    }

    // MARK: - Scoring (category-name keywords)

    private static func filteredOutfits(
        _ outfits: [SavedOutfit],
        band: WeatherComfortBand?,
        categoryNameForItemId: (UUID) -> String?
    ) -> [SavedOutfit] {
        guard let band else { return outfits }
        switch band {
        case .mild:
            return outfits
        case .cold:
            let m = outfits.filter { matchesCold($0, categoryNameForItemId) }
            return m.isEmpty ? outfits : m
        case .warm:
            let m = outfits.filter { matchesWarm($0, categoryNameForItemId) }
            return m.isEmpty ? outfits : m
        case .hot:
            let m = outfits.filter { matchesHot($0, categoryNameForItemId) }
            return m.isEmpty ? outfits : m
        }
    }

    private static func categoryNames(for outfit: SavedOutfit, resolver: (UUID) -> String?) -> [String] {
        outfit.itemIds.compactMap { resolver($0) }
    }

    private static func matchesCold(_ outfit: SavedOutfit, _ resolver: (UUID) -> String?) -> Bool {
        categoryNames(for: outfit, resolver: resolver).contains { name in
            let n = name.lowercased()
            return n.contains("outer") || n.contains("jacket") || n.contains("coat")
                || n.contains("sweater") || n.contains("knit") || n.contains("hoodie")
                || n.contains("fleece") || n.contains("cardigan") || n.contains("gilet")
        }
    }

    private static func matchesWarm(_ outfit: SavedOutfit, _ resolver: (UUID) -> String?) -> Bool {
        categoryNames(for: outfit, resolver: resolver).contains { name in
            let n = name.lowercased()
            return n.contains("top") || n.contains("tee") || n.contains("shirt")
                || n.contains("blouse") || n.contains("tank") || n.contains("polo")
                || n.contains("camisole") || n.contains("henley")
        }
    }

    private static func matchesHot(_ outfit: SavedOutfit, _ resolver: (UUID) -> String?) -> Bool {
        categoryNames(for: outfit, resolver: resolver).contains { name in
            let n = name.lowercased()
            return n.contains("short") || n.contains("skirt") || n.contains("sandal")
                || n.contains("dress") || n.contains("linen") || n.contains("swim")
                || n.contains("tank")
        }
    }

    // MARK: - Persistence

    func clearTodayPickPersisted() {
        defaults.removeObject(forKey: Keys.outfitId)
        defaults.removeObject(forKey: Keys.dayStart)
        defaults.removeObject(forKey: Keys.explanation)
    }

    private func clearPersistedLook() {
        clearTodayPickPersisted()
    }

    private static func startOfDayTimestamp(for date: Date) -> TimeInterval {
        Calendar.current.startOfDay(for: date).timeIntervalSince1970
    }
}
