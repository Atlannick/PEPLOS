//
//  FashionKnowledgeEngine.swift
//  PEPLOS
//
//  Local structured fashion intelligence entrypoint for Lucky Look.
//

import Foundation

enum FashionKnowledgeEngine {
    static func rankCandidates(
        candidates: [[ScorableFashionItem]],
        context: FashionEvaluationContext,
        recents: [LuckyLookRecencyRecord]
    ) -> [LuckyLookScoredCandidate] {
        let season = context.targetSeason ?? FashionRules.seasonForDate()
        let weather = FashionRuleLibrary.deriveWeatherContext(from: context)
        let lens = FashionRuleLibrary.inferOccasionLens(from: context)
        let trend = SeasonalTrendProfile.placeholder(for: season)

        let scored = candidates.map { rows in
            LuckyLookScoring.score(
                input: LuckyLookKnowledgeInput(
                    items: rows,
                    context: context,
                    occasionLens: lens,
                    weather: weather,
                    trendProfile: trend,
                    recentLooks: recents
                )
            )
        }
        return scored.sorted { $0.totalScore > $1.totalScore }
    }
}
