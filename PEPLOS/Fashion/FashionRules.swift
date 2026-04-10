//
//  FashionRules.swift
//  PEPLOS
//
//  Pure functions that interpret `FashionKnowledge` — color wheel math, occasion/season
//  overlap, category grammar, and silhouette/formality heuristics. Intended for reuse by
//  `FashionOutfitNarrativeBuilder`, pairing rankers, and AI grounding text.
//

import Foundation

/// Stateless helpers implementing the rule system described in comments throughout this module.
enum FashionRules {

    // MARK: - Color wheel

    /// Shortest angular distance between two hues on the wheel (0...180).
    static func hueDistanceDegrees(_ a: FashionColor, _ b: FashionColor) -> Double? {
        guard let ha = a.hueDegrees, let hb = b.hueDegrees else { return nil }
        let d = abs(ha - hb)
        return min(d, 360 - d)
    }

    /// True when hues sit roughly opposite on the wheel (complementary styling).
    static func isComplementaryPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        guard let d = hueDistanceDegrees(a, b) else { return false }
        return d >= 150 && d <= 210
    }

    /// Neighboring hues — harmonious, lower contrast than complements.
    static func isAnalogousPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        guard let d = hueDistanceDegrees(a, b) else { return false }
        return d <= 45
    }

    /// Strong light/dark or neutral vs chromatic contrast.
    static func isHighContrastPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        if a.isNeutral != b.isNeutral { return true }
        if a.isNeutral && b.isNeutral {
            return isNeutralContrastPair(a, b)
        }
        guard let d = hueDistanceDegrees(a, b) else { return false }
        return d >= 90
    }

    private static func isNeutralContrastPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        let light: Set<FashionColor> = [.white, .offWhite, .cream, .silver, .beige]
        let dark: Set<FashionColor> = [.black, .charcoal, .espresso, .navy]
        if light.contains(a), dark.contains(b) { return true }
        if light.contains(b), dark.contains(a) { return true }
        return false
    }

    /// True if the unordered pair appears in curated safe or classic lists.
    static func isCuratedSafePair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        let p = UnorderedPair(a, b)
        return FashionKnowledge.safeUniversalPairs.contains(p) || FashionKnowledge.strongClassicPairs.contains(p)
    }

    /// Known high-friction pair from `FashionKnowledge` (weighted, not a hard ban).
    static func isKnownClashPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        FashionKnowledge.commonlyClashingPairs.contains(UnorderedPair(a, b))
    }

    /// Monochrome / tonal: same family or neutrals within close grayscale.
    static func isTonalOrMonochrome(_ a: FashionColor, _ b: FashionColor) -> Bool {
        if a == b { return true }
        if a.isNeutral && b.isNeutral { return true }
        guard let d = hueDistanceDegrees(a, b) else { return a.isNeutral && b.isNeutral }
        return d <= 25
    }

    // MARK: - Aggregated color story

    struct ColorStory: Sendable {
        var neutralCount: Int
        var chromaticCount: Int
        var distinctHues: Int
        var curatedSafePairs: Int
        var complementaryPairs: Int
        var clashPairs: Int
        var boldColorCount: Int
    }

    static func analyzeColors(in items: [ScorableFashionItem]) -> ColorStory {
        let primaries = items.map(\.metadata.primaryColor)
        let secondaries = items.compactMap(\.metadata.secondaryColor)

        let neutrals = (primaries + secondaries).filter(\.isNeutral).count
        let chromatic = primaries.count + secondaries.count - neutrals

        let hues = (primaries + secondaries).compactMap(\.hueDegrees)
        let distinctHueBuckets = Set(hues.map { Int($0 / 30) }).count

        var curated = 0
        var comp = 0
        var clash = 0
        let allColors = primaries + secondaries
        for i in 0..<allColors.count {
            for j in (i + 1)..<allColors.count {
                let a = allColors[i]
                let b = allColors[j]
                if isCuratedSafePair(a, b) { curated += 1 }
                if isComplementaryPair(a, b) { comp += 1 }
                if isKnownClashPair(a, b) { clash += 1 }
            }
        }

        let bold = primaries.filter { $0.saturationTier >= 3 }.count
            + secondaries.filter { $0.saturationTier >= 3 }.count

        return ColorStory(
            neutralCount: neutrals,
            chromaticCount: chromatic,
            distinctHues: distinctHueBuckets,
            curatedSafePairs: curated,
            complementaryPairs: comp,
            clashPairs: clash,
            boldColorCount: bold
        )
    }

    // MARK: - Occasion & season fit

    /// How well items collectively support a target occasion (0...1).
    static func occasionCoherence(items: [ScorableFashionItem], target: FashionOccasion) -> Double {
        guard !items.isEmpty else { return 0 }
        let profile = FashionKnowledge.occasionProfile(target)
        var score = 0.0
        for item in items {
            if item.metadata.suitableOccasions.contains(target) {
                score += 1
            } else if item.metadata.suitableOccasions.contains(.everyday) {
                score += 0.65
            } else {
                score += 0.25
            }
            let f = item.metadata.formality
            if profile.idealFormalityRange.contains(f) {
                score += 0.35
            } else if profile.idealFormalityRange.lowerBound == .ultraCasual, f == .ultraCasual {
                score += 0.35
            } else {
                let dist = min(
                    abs(f.rawValue - profile.idealFormalityRange.lowerBound.rawValue),
                    abs(f.rawValue - profile.idealFormalityRange.upperBound.rawValue)
                )
                score += max(0, 0.35 - Double(dist) * 0.08)
            }
        }
        let maxPer = 1.35
        return min(1, score / (Double(items.count) * maxPer))
    }

    /// Season alignment for a set of items vs a target season (0...1).
    static func seasonCoherence(items: [ScorableFashionItem], target: FashionSeason) -> Double {
        guard !items.isEmpty else { return 0 }
        let palette = FashionKnowledge.seasonalPalette(target)
        var s = 0.0
        for item in items {
            if item.metadata.suitableSeasons.contains(target) {
                s += 1
            } else {
                s += 0.35
            }
            if palette.contains(item.metadata.primaryColor) { s += 0.35 }
            if let sec = item.metadata.secondaryColor, palette.contains(sec) { s += 0.2 }
        }
        return min(1, s / (Double(items.count) * 1.55))
    }

    /// Warmth vs season expectation (light summer vs heavy winter).
    static func warmthVsSeason(items: [ScorableFashionItem], target: FashionSeason) -> Double {
        guard !items.isEmpty else { return 0 }
        let expectation = FashionKnowledge.seasonProfile(target).layeringExpectation
        func weight(_ w: FashionWarmth) -> Double {
            switch (expectation, w) {
            case (.light, .coolLightweight), (.light, .allSeason): return 1
            case (.moderate, .allSeason): return 1
            case (.moderate, .warmMidweight), (.moderate, .coolLightweight): return 0.85
            case (.heavy, .warmMidweight), (.heavy, .coldHeavyweight), (.heavy, .allSeason): return 1
            case (.light, .warmMidweight), (.light, .coldHeavyweight): return 0.35
            case (.heavy, .coolLightweight): return 0.45
            default: return 0.65
            }
        }
        let avg = items.map { weight($0.metadata.warmth) }.reduce(0, +) / Double(items.count)
        return avg
    }

    // MARK: - Category completeness

    struct Completeness: Sendable {
        var hasDress: Bool
        var hasTopOrDress: Bool
        var hasBottomOrDress: Bool
        var hasShoes: Bool
        var hasOuterwear: Bool
        var categoryCount: Int
    }

    static func completeness(of items: [ScorableFashionItem]) -> Completeness {
        let cats = Set(items.map(\.metadata.category))
        let hasDress = cats.contains(.dress)
        let hasTop = cats.contains(.top) || cats.contains(.layer)
        let hasBottom = cats.contains(.bottom)
        let hasShoes = cats.contains(.shoes)
        let hasOuter = cats.contains(.outerwear)
        return Completeness(
            hasDress: hasDress,
            hasTopOrDress: hasDress || hasTop,
            hasBottomOrDress: hasDress || hasBottom,
            hasShoes: hasShoes,
            hasOuterwear: hasOuter,
            categoryCount: cats.count
        )
    }

    /// 0...1 score for having a wearable core (top+bottom+shoes or dress+shoes).
    static func completenessScore(_ c: Completeness) -> Double {
        if c.hasBottomOrDress, c.hasTopOrDress, c.hasShoes { return 1 }
        if c.hasDress, c.hasShoes { return 0.95 }
        if c.hasTopOrDress, c.hasBottomOrDress { return 0.55 }
        if c.hasTopOrDress, c.hasShoes { return 0.5 }
        return 0.25
    }

    // MARK: - Balance: fit & statements

    struct BalanceReport: Sendable {
        var looseCount: Int
        var fittedCount: Int
        var statementCount: Int
    }

    static func balanceReport(items: [ScorableFashionItem]) -> BalanceReport {
        var loose = 0
        var fitted = 0
        var statements = 0
        for i in items {
            switch i.metadata.fit {
            case .oversized, .relaxed: loose += 1
            case .slim, .regular: fitted += 1
            }
            if i.metadata.statementLevel != .none { statements += 1 }
        }
        return BalanceReport(looseCount: loose, fittedCount: fitted, statementCount: statements)
    }

    /// Prefer mixing oversized with slimmer pieces to avoid shapelessness.
    static func silhouetteBalanceScore(_ b: BalanceReport) -> Double {
        if b.looseCount >= 2, b.fittedCount == 0 { return 0.45 }
        if b.looseCount >= 1, b.fittedCount >= 1 { return 1 }
        if b.looseCount == 0, b.fittedCount >= 2 { return 0.9 }
        return 0.75
    }

    static func statementPenalty(_ b: BalanceReport) -> Double {
        switch b.statementCount {
        case 0, 1: return 0
        case 2: return 0.08
        default: return 0.22
        }
    }

    // MARK: - Formality spread & shoes

    static func formalitySpread(items: [ScorableFashionItem]) -> Int {
        let vals = items.map(\.metadata.formality.rawValue)
        guard let minV = vals.min(), let maxV = vals.max() else { return 0 }
        return maxV - minV
    }

    /// Penalize when shoes are far more casual than the outfit's average formality.
    static func shoeFormalityAlignment(items: [ScorableFashionItem]) -> Double {
        let shoes = items.filter { $0.metadata.category == .shoes }
        guard !shoes.isEmpty else { return 0.75 }
        let others = items.filter { $0.metadata.category != .shoes }
        guard !others.isEmpty else { return 1 }
        let avg = others.map { Double($0.metadata.formality.rawValue) }.reduce(0, +) / Double(others.count)
        let shoe = shoes.map { Double($0.metadata.formality.rawValue) }.reduce(0, +) / Double(shoes.count)
        let delta = abs(avg - shoe)
        if delta <= 1 { return 1 }
        if delta <= 2 { return 0.82 }
        return max(0.35, 0.82 - (delta - 2) * 0.15)
    }

    // MARK: - Style tag coherence

    static func styleTagOverlap(items: [ScorableFashionItem]) -> Double {
        guard items.count >= 2 else { return 1 }
        var inter = items.first!.metadata.styleTags
        for i in items.dropFirst() {
            inter = inter.intersection(i.metadata.styleTags)
        }
        if !inter.isEmpty { return 1 }
        // Partial overlap: any shared tag between any pair
        var best = 0
        for i in 0..<items.count {
            for j in (i + 1)..<items.count {
                let c = items[i].metadata.styleTags.intersection(items[j].metadata.styleTags).count
                best = max(best, c)
            }
        }
        return best > 0 ? 0.75 : 0.5
    }

    // MARK: - Future pairing / ranking hooks

    /// Quick 0...1 affinity for two items (for future match lists).
    static func pairwiseAffinity(_ a: ScorableFashionItem, _ b: ScorableFashionItem) -> Double {
        var s = 0.5
        let c1 = a.metadata.primaryColor
        let c2 = b.metadata.primaryColor
        if isCuratedSafePair(c1, c2) { s += 0.25 }
        if isTonalOrMonochrome(c1, c2) { s += 0.15 }
        if isComplementaryPair(c1, c2) { s += 0.12 }
        if isKnownClashPair(c1, c2) { s -= 0.2 }

        let occ = a.metadata.suitableOccasions.intersection(b.metadata.suitableOccasions)
        if !occ.isEmpty { s += 0.12 }
        let sea = a.metadata.suitableSeasons.intersection(b.metadata.suitableSeasons)
        if !sea.isEmpty { s += 0.08 }

        let catPair = UnorderedCategoryPair(a.metadata.category, b.metadata.category)
        if FashionKnowledge.naturalCategoryPairs.contains(catPair) { s += 0.1 }

        return min(1, max(0, s))
    }

    /// Rank multiple candidate outfits by average pairwise affinity (lightweight).
    static func rankOutfitCandidates(_ outfits: [[ScorableFashionItem]]) -> [[ScorableFashionItem]] {
        func score(_ o: [ScorableFashionItem]) -> Double {
            guard o.count >= 2 else { return 0 }
            var t = 0.0
            var n = 0
            for i in 0..<o.count {
                for j in (i + 1)..<o.count {
                    t += pairwiseAffinity(o[i], o[j])
                    n += 1
                }
            }
            return t / Double(n)
        }
        return outfits.sorted { score($0) > score($1) }
    }

    /// Whether the engine suggests rejecting a combo for a minimum viable outfit (strict mode).
    static func shouldRejectWeakCombination(items: [ScorableFashionItem], context: FashionEvaluationContext) -> Bool {
        let c = completeness(of: items)
        let cs = completenessScore(c)
        if context.strictCompleteness, cs < 0.5 { return true }
        let colors = analyzeColors(in: items)
        if colors.clashPairs >= 2, colors.curatedSafePairs == 0 { return true }
        return false
    }

    // MARK: - Weather (local temperature bands, °C)

    /// How well an outfit's warmth and layering match the current temperature. Returns 0...1.
    static func weatherOutfitAlignment(items: [ScorableFashionItem], celsius: Double) -> Double {
        guard !items.isEmpty else { return 0.5 }
        enum Band { case cold, mild, warm, hot }
        let band: Band
        switch celsius {
        case ..<10: band = .cold
        case 10..<18: band = .mild
        case 18..<26: band = .warm
        default: band = .hot
        }

        let hasOuter = items.contains { $0.metadata.category == .outerwear }
        let avgWarmth =
            items
            .map { item -> Double in
                switch item.metadata.warmth {
                case .coolLightweight: return 0
                case .allSeason: return 0.5
                case .warmMidweight: return 0.75
                case .coldHeavyweight: return 1
                }
            }
            .reduce(0, +) / Double(items.count)

        switch band {
        case .cold:
            var s = 0.55 + avgWarmth * 0.35
            if hasOuter { s += 0.12 }
            return min(1, s)
        case .mild:
            return max(0.45, 0.78 - abs(avgWarmth - 0.5) * 0.35)
        case .warm:
            var s = 0.58 + (1 - avgWarmth) * 0.35
            if hasOuter { s -= 0.05 }
            return min(1, max(0, s))
        case .hot:
            var s = 0.55 + (1 - avgWarmth) * 0.42
            if hasOuter { s -= 0.1 }
            return min(1, max(0, s))
        }
    }

    /// Calendar season for a date (Northern Hemisphere convention).
    static func seasonForDate(_ date: Date = .init()) -> FashionSeason {
        let m = Calendar.current.component(.month, from: date)
        switch m {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}
