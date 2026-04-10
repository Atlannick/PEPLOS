//
//  FashionEngine.swift
//  PEPLOS
//
//  Single entry surface for outfit intelligence: narrative notes, ranking, pairwise explanation,
//  and rejection gates. Call these from stylists, outfit builders, or future AI layers —
//  everything stays on-device using `FashionKnowledge` + `FashionRules`.
//

import Foundation

/// App-facing facade so features do not need to import or know about individual modules.
enum FashionEngine {

    /// Strengths, caveats, and short summaries from local rules (no numeric score).
    static func outfitNarrative(
        items: [ScorableFashionItem],
        context: FashionEvaluationContext = FashionEvaluationContext()
    ) -> FashionOutfitNarrative {
        FashionOutfitNarrativeBuilder.build(items: items, context: context)
    }

    /// Rank candidate outfits (e.g. combinations from the closet) by average pairwise harmony.
    static func rankOutfitCandidates(_ outfits: [[ScorableFashionItem]]) -> [[ScorableFashionItem]] {
        FashionRules.rankOutfitCandidates(outfits)
    }

    /// Whether an outfit should be filtered out in strict flows (e.g. builder “hard reject”).
    static func shouldRejectCombination(
        items: [ScorableFashionItem],
        context: FashionEvaluationContext
    ) -> Bool {
        FashionRules.shouldRejectWeakCombination(items: items, context: context)
    }

    /// Short rationale for why two items work together (for match lists / explanations).
    static func explainPairing(_ a: ScorableFashionItem, _ b: ScorableFashionItem) -> [String] {
        var lines: [String] = []
        let c1 = a.metadata.primaryColor
        let c2 = b.metadata.primaryColor
        if FashionRules.isCuratedSafePair(c1, c2) {
            lines.append("These colors sit in a classic, widely accepted pairing.")
        }
        if FashionRules.isTonalOrMonochrome(c1, c2) {
            lines.append("Tonal or monochrome harmony keeps the look cohesive.")
        }
        if FashionRules.isComplementaryPair(c1, c2) {
            lines.append("Complementary hues create clear, intentional contrast.")
        }
        let aff = FashionRules.pairwiseAffinity(a, b)
        lines.append(String(format: "Pairwise harmony index: %.0f%%.", aff * 100))
        if lines.isEmpty {
            lines.append("General compatibility based on occasion, season, and category pairing.")
        }
        return lines
    }

    /// Map user-defined closet category names (English) to engine slots — best-effort for future auto-tagging.
    static func inferFashionCategory(fromClosetCategoryName name: String) -> FashionItemCategory? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if n.contains("top") || n.contains("shirt") || n.contains("tee") || n.contains("blouse") || n.contains("sweater") {
            return .top
        }
        if n.contains("bottom") || n.contains("pant") || n.contains("jean") || n.contains("short") || n.contains("skirt") {
            return .bottom
        }
        if n.contains("dress") { return .dress }
        if n.contains("shoe") || n.contains("boot") || n.contains("sneaker") || n.contains("sandal") || n.contains("loafer") {
            return .shoes
        }
        if n.contains("outer") || n.contains("coat") || n.contains("jacket") || n.contains("blazer") {
            return .outerwear
        }
        if n.contains("hat") || n.contains("cap") { return .hat }
        if n.contains("bag") || n.contains("purse") || n.contains("tote") { return .bag }
        if n.contains("accessor") || n.contains("belt") || n.contains("scarf") || n.contains("jewel") {
            return .accessory
        }
        return nil
    }
}
