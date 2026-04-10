//
//  FashionKnowledgeModels.swift
//  PEPLOS
//
//  Lightweight local fashion-intelligence models for Lucky Look scoring.
//

import Foundation

enum StylePersonalityTag: String, CaseIterable, Codable, Hashable, Sendable {
    case classic
    case minimalist
    case casual
    case elegant
    case edgy
    case sporty
    case relaxed
    case statement
    case street
    case clean
}

enum LuckyLookOccasionLens: String, CaseIterable, Codable, Hashable, Sendable {
    case casual
    case smartCasual
    case formalDinner
    case relaxedHome
    case travel
    case weatherBasedDailyUse
}

enum WeatherMood: String, CaseIterable, Codable, Hashable, Sendable {
    case clear
    case rainy
    case hot
    case cold
    case mild
}

struct WeatherStyleContext: Codable, Hashable, Sendable {
    var temperatureCelsius: Double?
    var rainLikely: Bool
    var mood: WeatherMood
}

struct SeasonalTrendProfile: Codable, Hashable, Sendable {
    var season: FashionSeason
    var currentSeasonKeywords: [String]
    var trendAccents: [FashionColor]
    var trendColors: [FashionColor]

    static func placeholder(for season: FashionSeason) -> SeasonalTrendProfile {
        switch season {
        case .spring:
            return SeasonalTrendProfile(
                season: .spring,
                currentSeasonKeywords: ["fresh layers", "clean contrast", "soft color"],
                trendAccents: [.sage, .powderBlue],
                trendColors: [.white, .cream, .sage, .powderBlue]
            )
        case .summer:
            return SeasonalTrendProfile(
                season: .summer,
                currentSeasonKeywords: ["breathable", "light palette", "easy polish"],
                trendAccents: [.coral, .teal],
                trendColors: [.white, .offWhite, .coral, .teal]
            )
        case .autumn:
            return SeasonalTrendProfile(
                season: .autumn,
                currentSeasonKeywords: ["rich texture", "earth tones", "structured layers"],
                trendAccents: [.rust, .olive],
                trendColors: [.cream, .olive, .rust, .charcoal]
            )
        case .winter:
            return SeasonalTrendProfile(
                season: .winter,
                currentSeasonKeywords: ["structured warmth", "deep tones", "clean layers"],
                trendAccents: [.burgundy, .forest],
                trendColors: [.black, .charcoal, .burgundy, .forest]
            )
        }
    }
}

struct LuckyLookRecencyRecord: Codable, Hashable, Sendable {
    var generatedAt: Date
    var sortedItemIds: [UUID]
}

struct LuckyLookKnowledgeInput: Sendable {
    var items: [ScorableFashionItem]
    var context: FashionEvaluationContext
    var occasionLens: LuckyLookOccasionLens
    var weather: WeatherStyleContext
    var trendProfile: SeasonalTrendProfile
    var recentLooks: [LuckyLookRecencyRecord]
}
