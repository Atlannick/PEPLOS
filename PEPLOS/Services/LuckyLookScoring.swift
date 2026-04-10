//
//  LuckyLookScoring.swift
//  PEPLOS
//
//  Multi-factor outfit scoring and stylist-facing explanation text.
//

import Foundation

struct LuckyLookFactorScores: Sendable {
    var colorHarmony: Double
    var silhouetteBalance: Double
    var weatherSuitability: Double
    var occasionFit: Double
    var materialCompatibility: Double
    var wardrobeFreshness: Double
    var confidencePolish: Double
    var composition: Double
    var styleCoherence: Double

    var weightedTotal: Double {
        (colorHarmony * 0.18)
            + (silhouetteBalance * 0.14)
            + (weatherSuitability * 0.16)
            + (occasionFit * 0.13)
            + (materialCompatibility * 0.11)
            + (wardrobeFreshness * 0.1)
            + (confidencePolish * 0.1)
            + (composition * 0.05)
            + (styleCoherence * 0.03)
    }
}

struct LuckyLookScoredCandidate: Sendable {
    var items: [ScorableFashionItem]
    var factors: LuckyLookFactorScores
    var totalScore: Double
    var explanation: String
    var strengths: [String]
}

enum LuckyLookScoring {
    static func score(input: LuckyLookKnowledgeInput) -> LuckyLookScoredCandidate {
        let items = input.items
        let colors = FashionRules.analyzeColors(in: items)
        let balance = FashionRules.balanceReport(items: items)
        let complete = FashionRules.completeness(of: items)

        let color = colorScore(colors: colors)
        let silhouette = silhouetteScore(items: items, balance: balance)
        let weather = weatherScore(items: items, weather: input.weather)
        let occasion = occasionScore(items: items, occasion: input.occasionLens, context: input.context)
        let material = materialScore(items: items, weather: input.weather)
        let freshness = freshnessScore(items: items, recents: input.recentLooks)
        let confidence = confidenceScore(items: items, balance: balance)
        let composition = compositionScore(items: items, completeness: complete)
        let style = styleCoherenceScore(items: items)

        let factors = LuckyLookFactorScores(
            colorHarmony: color,
            silhouetteBalance: silhouette,
            weatherSuitability: weather,
            occasionFit: occasion,
            materialCompatibility: material,
            wardrobeFreshness: freshness,
            confidencePolish: confidence,
            composition: composition,
            styleCoherence: style
        )
        let strengths = strengths(
            items: items,
            colors: colors,
            weather: input.weather,
            silhouette: silhouette,
            composition: composition
        )
        let explanation = explanation(
            items: items,
            colors: colors,
            weather: input.weather,
            silhouette: silhouette,
            composition: composition,
            style: style
        )

        return LuckyLookScoredCandidate(
            items: items,
            factors: factors,
            totalScore: factors.weightedTotal,
            explanation: explanation,
            strengths: strengths
        )
    }

    private static func colorScore(colors: FashionRules.ColorStory) -> Double {
        var s = 0.58
        if colors.neutralCount >= 2 { s += 0.15 }
        if colors.complementaryPairs > 0 || colors.curatedSafePairs > 0 { s += 0.12 }
        if colors.distinctHues <= 2 { s += 0.09 }
        if colors.clashPairs > 0 { s -= min(0.28, Double(colors.clashPairs) * 0.14) }
        if colors.boldColorCount > 1 { s -= 0.1 }
        return clamp(s)
    }

    private static func silhouetteScore(items: [ScorableFashionItem], balance: FashionRules.BalanceReport) -> Double {
        var s = FashionRules.silhouetteBalanceScore(balance)
        let topFit = items.first(where: { $0.metadata.category == .top })?.metadata.fit
        let bottomFit = items.first(where: { $0.metadata.category == .bottom })?.metadata.fit
        if topFit == .oversized, bottomFit == .oversized {
            s -= 0.2
        } else if (topFit == .slim || topFit == .regular), (bottomFit == .relaxed || bottomFit == .oversized) {
            s += 0.08
        } else if (bottomFit == .slim || bottomFit == .regular), (topFit == .relaxed || topFit == .oversized) {
            s += 0.08
        }
        return clamp(s)
    }

    private static func weatherScore(items: [ScorableFashionItem], weather: WeatherStyleContext) -> Double {
        guard let c = weather.temperatureCelsius else { return 0.72 }
        var s = FashionRules.weatherOutfitAlignment(items: items, celsius: c)
        let hasOuter = items.contains { $0.metadata.category == .outerwear }
        if c < 10, hasOuter { s += 0.12 }
        if c > 27, hasOuter { s -= 0.12 }
        if weather.rainLikely {
            if items.contains(where: { !$0.metadata.fabrics.intersection(FashionRuleLibrary.delicateRainRiskFabrics).isEmpty }) {
                s -= 0.18
            }
            if hasOuter { s += 0.06 }
        }
        return clamp(s)
    }

    private static func occasionScore(
        items: [ScorableFashionItem],
        occasion: LuckyLookOccasionLens,
        context: FashionEvaluationContext
    ) -> Double {
        let mapped: FashionOccasion = {
            switch occasion {
            case .casual, .relaxedHome, .weatherBasedDailyUse: return .casual
            case .smartCasual, .travel: return .smartCasual
            case .formalDinner: return .evening
            }
        }()
        var s = FashionRules.occasionCoherence(items: items, target: context.targetOccasion ?? mapped)
        if occasion == .travel {
            let hasSneakerish = items.contains { $0.metadata.category == .shoes && $0.metadata.formality <= .casual }
            if hasSneakerish { s += 0.08 }
        }
        return clamp(s)
    }

    private static func materialScore(items: [ScorableFashionItem], weather: WeatherStyleContext) -> Double {
        let fabrics = items.flatMap { Array($0.metadata.fabrics) }
        if fabrics.isEmpty { return 0.68 }
        var s = 0.62
        if fabrics.contains(.denim) { s += 0.08 }
        if fabrics.contains(.leather) { s += 0.05 }
        if fabrics.contains(.knit) { s += 0.05 }
        if fabrics.contains(.linen) || fabrics.contains(.cotton) {
            if (weather.temperatureCelsius ?? 22) >= 20 { s += 0.08 }
        }
        if fabrics.contains(where: FashionRuleLibrary.selectiveShineFabrics.contains),
           items.filter({ $0.metadata.statementLevel != .none }).count > 1 {
            s -= 0.08
        }
        return clamp(s)
    }

    private static func freshnessScore(items: [ScorableFashionItem], recents: [LuckyLookRecencyRecord]) -> Double {
        let ids = Set(items.compactMap(\.id))
        guard !ids.isEmpty else { return 0.7 }
        var penalty = 0.0
        for record in recents.prefix(10) {
            let overlap = ids.intersection(Set(record.sortedItemIds)).count
            if overlap == ids.count, record.sortedItemIds.count == ids.count {
                penalty += 0.45
            } else if !ids.isEmpty {
                penalty += Double(overlap) / Double(ids.count) * 0.18
            }
        }
        return clamp(1 - min(0.78, penalty))
    }

    private static func confidenceScore(items: [ScorableFashionItem], balance: FashionRules.BalanceReport) -> Double {
        var s = 0.62
        s += FashionRules.shoeFormalityAlignment(items: items) * 0.18
        s += FashionRules.styleTagOverlap(items: items) * 0.14
        s -= FashionRules.statementPenalty(balance)
        if items.contains(where: { $0.metadata.category == .outerwear && $0.metadata.formality >= .smartCasual }) {
            s += 0.06
        }
        return clamp(s)
    }

    private static func compositionScore(items: [ScorableFashionItem], completeness: FashionRules.Completeness) -> Double {
        var s = FashionRules.completenessScore(completeness)
        if completeness.hasOuterwear { s += 0.05 }
        if !completeness.hasShoes { s -= 0.25 }
        return clamp(s)
    }

    private static func styleCoherenceScore(items: [ScorableFashionItem]) -> Double {
        guard !items.isEmpty else { return 0.5 }
        let personalitySets = items.map { FashionRuleLibrary.stylePersonality(for: $0.metadata) }
        var shared = personalitySets.first ?? []
        for tagSet in personalitySets.dropFirst() {
            shared = shared.intersection(tagSet)
        }
        if !shared.isEmpty { return 1 }
        let pairwise = FashionRules.styleTagOverlap(items: items)
        return clamp(pairwise)
    }

    private static func strengths(
        items: [ScorableFashionItem],
        colors: FashionRules.ColorStory,
        weather: WeatherStyleContext,
        silhouette: Double,
        composition: Double
    ) -> [String] {
        var lines: [String] = []
        if colors.neutralCount >= 2 {
            lines.append("Balanced proportions with a clean neutral palette.")
        }
        if let temp = weather.temperatureCelsius, temp < 14,
           items.contains(where: { $0.metadata.category == .outerwear }) {
            lines.append("Light layers work well for today’s temperature.")
        }
        if items.contains(where: { $0.metadata.category == .outerwear }) {
            lines.append("The jacket gives structure while keeping the look casual.")
        }
        if colors.boldColorCount == 1 {
            lines.append("A strong statement piece is balanced by simpler basics.")
        }
        if silhouette > 0.82 {
            lines.append("Fitted and relaxed pieces are balanced for a flattering silhouette.")
        }
        if composition > 0.8 {
            lines.append("Core outfit composition is complete and visually coherent.")
        }
        if lines.isEmpty {
            lines.append("This look stays cohesive while keeping enough contrast to feel styled.")
        }
        return Array(lines.prefix(6))
    }

    private static func explanation(
        items: [ScorableFashionItem],
        colors: FashionRules.ColorStory,
        weather: WeatherStyleContext,
        silhouette: Double,
        composition: Double,
        style: Double
    ) -> String {
        if colors.boldColorCount == 1, colors.neutralCount >= 2 {
            return "A single statement element is anchored by calm neutrals for a polished outfit."
        }
        if weather.rainLikely, items.contains(where: { $0.metadata.category == .outerwear }) {
            return "Weather-aware layering keeps this look practical while still feeling intentional."
        }
        if silhouette > 0.82 {
            return "Balanced proportions and clean styling make this outfit read confidently."
        }
        if composition >= 0.9, style >= 0.8 {
            return "The pieces share a coherent style direction with complete outfit structure."
        }
        return "This outfit works because color, shape, and occasion cues are aligned."
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
