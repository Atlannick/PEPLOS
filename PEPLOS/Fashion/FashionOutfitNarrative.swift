//
//  FashionOutfitNarrative.swift
//  PEPLOS
//
//  Rule-based outfit notes: strengths, weaknesses, and short explanations from
//  `FashionRules` — no numeric style score.
//

import Foundation

enum FashionOutfitNarrativeBuilder {

    static func build(
        items: [ScorableFashionItem],
        context: FashionEvaluationContext = FashionEvaluationContext()
    ) -> FashionOutfitNarrative {
        guard !items.isEmpty else {
            return FashionOutfitNarrative(
                summaryLines: ["Add clothing items to describe an outfit."],
                strengths: [],
                weaknesses: ["No items in outfit."],
                explanations: []
            )
        }

        let colorStory = FashionRules.analyzeColors(in: items)
        let colorScore = colorHarmonyScore(colorStory)

        let occasionTarget = context.targetOccasion ?? inferDominantOccasion(from: items)
        let occasionScore = FashionRules.occasionCoherence(items: items, target: occasionTarget)

        let seasonTarget = context.targetSeason ?? .spring
        let seasonScore = FashionRules.seasonCoherence(items: items, target: seasonTarget)
        let warmthScore = FashionRules.warmthVsSeason(items: items, target: seasonTarget)
        let blendedSeason = 0.65 * seasonScore + 0.35 * warmthScore

        let comp = FashionRules.completeness(of: items)
        let completenessScore = FashionRules.completenessScore(comp)

        let bal = FashionRules.balanceReport(items: items)

        let shoeAlign = FashionRules.shoeFormalityAlignment(items: items)
        let spread = FashionRules.formalitySpread(items: items)
        let formalityScore = max(0, min(1, shoeAlign * (spread <= 3 ? 1 : 0.88)))

        let styleTagOverlap = FashionRules.styleTagOverlap(items: items)

        let explanations = buildExplanations(
            colorStory: colorStory,
            colorScore: colorScore,
            occasion: occasionTarget,
            occasionScore: occasionScore,
            season: seasonTarget,
            blendedSeason: blendedSeason,
            completeness: comp,
            completenessScore: completenessScore,
            balance: bal,
            formalityScore: formalityScore,
            shoeAlign: shoeAlign,
            styleTagOverlap: styleTagOverlap,
            items: items
        )

        let strengths = explanations.filter { !$0.hasPrefix("—") }.map { String($0) }
        let weaknesses = explanations.filter { $0.hasPrefix("—") }.map {
            String($0.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        let summary = buildSummaryLines(
            colorStory: colorStory,
            comp: comp,
            occasion: occasionTarget,
            season: seasonTarget
        )

        return FashionOutfitNarrative(
            summaryLines: summary,
            strengths: strengths,
            weaknesses: weaknesses,
            explanations: explanations.map { String($0) }
        )
    }

    // MARK: - Sub-scores (for narrative thresholds only)

    private static func colorHarmonyScore(_ s: FashionRules.ColorStory) -> Double {
        var x = 0.55

        if s.neutralCount >= 1, s.chromaticCount >= 1 { x += 0.12 }
        if s.curatedSafePairs > 0 { x += min(0.2, Double(s.curatedSafePairs) * 0.07) }
        if s.complementaryPairs > 0 { x += min(0.12, Double(s.complementaryPairs) * 0.06) }
        if s.distinctHues >= 4 { x -= 0.12 }
        if s.boldColorCount >= 3 { x -= 0.1 }
        if s.clashPairs > 0 { x -= min(0.22, Double(s.clashPairs) * 0.1) }
        if s.neutralCount == 0, s.chromaticCount >= 3 { x -= 0.08 }

        return max(0, min(1, x))
    }

    private static func inferDominantOccasion(from items: [ScorableFashionItem]) -> FashionOccasion {
        var counts: [FashionOccasion: Int] = [:]
        for o in FashionOccasion.allCases { counts[o] = 0 }
        for i in items {
            for o in i.metadata.suitableOccasions {
                counts[o, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .everyday
    }

    // MARK: - Narrative

    private static func buildSummaryLines(
        colorStory: FashionRules.ColorStory,
        comp: FashionRules.Completeness,
        occasion: FashionOccasion,
        season: FashionSeason
    ) -> [String] {
        var lines: [String] = []
        if colorStory.curatedSafePairs > 0 {
            lines.append("Strong neutral or classic color pairing.")
        }
        if comp.hasTopOrDress, comp.hasBottomOrDress, comp.hasShoes {
            lines.append("Core outfit slots (top/bottom or dress + shoes) look complete.")
        }
        lines.append("Optimized lens: \(humanOccasion(occasion)) · \(season.rawValue).")
        return lines
    }

    private static func humanOccasion(_ o: FashionOccasion) -> String {
        switch o {
        case .smartCasual: return "smart casual"
        case .businessCasual: return "business casual"
        case .vacationBeach: return "vacation or beach"
        default: return o.rawValue
        }
    }

    private static func buildExplanations(
        colorStory: FashionRules.ColorStory,
        colorScore: Double,
        occasion: FashionOccasion,
        occasionScore: Double,
        season: FashionSeason,
        blendedSeason: Double,
        completeness: FashionRules.Completeness,
        completenessScore: Double,
        balance: FashionRules.BalanceReport,
        formalityScore: Double,
        shoeAlign: Double,
        styleTagOverlap: Double,
        items: [ScorableFashionItem]
    ) -> [String] {
        var lines: [String] = []

        if colorScore >= 0.78 {
            lines.append("Strong neutral color combination.")
        } else if colorStory.curatedSafePairs > 0 {
            lines.append("Classic, low-risk color pairing.")
        }

        if colorStory.complementaryPairs > 0, colorStory.clashPairs == 0 {
            lines.append("Complementary colors add intentional contrast.")
        }

        if colorStory.distinctHues >= 4 {
            lines.append("— Too many competing statement colors.")
        }

        if colorStory.clashPairs > 0 {
            lines.append("— Some hues may fight each other unless softened with neutrals.")
        }

        if occasionScore >= 0.72 {
            lines.append("Good balance for \(humanOccasion(occasion)) styling.")
        } else if occasionScore < 0.45 {
            lines.append("— Occasion fit is mixed; anchor with shoes or outerwear closer to the brief.")
        }

        if blendedSeason < 0.5 {
            lines.append("— Season palette and fabric weight feel misaligned with \(season.rawValue).")
        } else if blendedSeason >= 0.8 {
            lines.append("Season-appropriate colors and weight.")
        }

        let warmthLow = FashionRules.warmthVsSeason(items: items, target: season) < 0.5
        if season == .summer, warmthLow {
            lines.append("— This outfit may feel too heavy for warm weather.")
        }
        if season == .winter, FashionRules.warmthVsSeason(items: items, target: season) < 0.55 {
            lines.append("— Consider warmer layers or outerwear for cold weather.")
        }

        if completenessScore >= 0.9 {
            lines.append("Outfit completeness looks solid for everyday wear.")
        } else if completenessScore < 0.55 {
            lines.append("— Add core pieces (top + bottom or dress, and shoes) for balance.")
        }

        if balance.looseCount >= 2, balance.fittedCount == 0 {
            lines.append("— Try balancing oversized pieces with something more fitted.")
        } else if balance.looseCount >= 1, balance.fittedCount >= 1 {
            lines.append("Balanced loose and fitted silhouette.")
        }

        if balance.statementCount > 2 {
            lines.append("— Too many competing statement pieces; let one lead.")
        }

        if shoeAlign < 0.7 {
            lines.append("— Formal shoes improve the overall balance.")
        } else if shoeAlign >= 0.9 {
            lines.append("Shoe formality matches the rest of the outfit.")
        }

        if formalityScore < 0.65 {
            lines.append("— Formality is uneven across items; align layers and footwear.")
        }

        if items.contains(where: { $0.metadata.category == .outerwear }) {
            lines.append("Outerwear helps anchor the look.")
        }

        if styleTagOverlap >= 0.85 {
            lines.append("Shared style direction across pieces.")
        }

        if lines.isEmpty {
            lines.append("Balanced outfit with room to refine color and accessories.")
        }

        return lines
    }
}

#if DEBUG
enum FashionOutfitNarrativeDemo {
    static func sampleReport() -> String {
        let items: [ScorableFashionItem] = [
            ScorableFashionItem(metadata: FashionItemMetadata(
                category: .top,
                primaryColor: .white,
                secondaryColor: .navy,
                suitableSeasons: [.spring, .summer],
                suitableOccasions: [.smartCasual, .everyday],
                styleTags: [.classic, .minimal],
                formality: .smartCasual,
                warmth: .allSeason,
                fit: .regular,
                statementLevel: .none,
                fabrics: [.cotton]
            )),
            ScorableFashionItem(metadata: FashionItemMetadata(
                category: .bottom,
                primaryColor: .navy,
                suitableSeasons: Set(FashionSeason.allCases),
                suitableOccasions: [.smartCasual, .businessCasual, .everyday],
                styleTags: [.classic],
                formality: .smartCasual,
                warmth: .allSeason,
                fit: .slim,
                statementLevel: .none,
                fabrics: [.denim]
            )),
            ScorableFashionItem(metadata: FashionItemMetadata(
                category: .shoes,
                primaryColor: .brown,
                suitableSeasons: [.spring, .autumn],
                suitableOccasions: [.smartCasual, .everyday],
                styleTags: [.classic],
                formality: .smartCasual,
                warmth: .allSeason,
                fit: .regular,
                statementLevel: .none,
                fabrics: [.leather]
            )),
        ]

        let ctx = FashionEvaluationContext(targetOccasion: .smartCasual, targetSeason: .spring, strictCompleteness: false)
        let r = FashionOutfitNarrativeBuilder.build(items: items, context: ctx)

        var s = "=== FashionOutfitNarrativeDemo ===\n"
        s += "Summary:\n"
        for line in r.summaryLines { s += "  • \(line)\n" }
        s += "Strengths:\n"
        for line in r.strengths { s += "  + \(line)\n" }
        s += "Weaknesses / warnings:\n"
        for line in r.weaknesses { s += "  ! \(line)\n" }
        s += "All explanations:\n"
        for line in r.explanations { s += "  - \(line)\n" }
        return s
    }
}
#endif
