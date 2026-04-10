//
//  FashionRuleLibrary.swift
//  PEPLOS
//
//  Timeless local styling heuristics for Lucky Look v1.
//

import Foundation

enum FashionRuleLibrary {
    static let neutralAnchors: Set<FashionColor> = FashionKnowledge.neutralColors

    static let warmWeatherFabrics: Set<FashionFabric> = [.linen, .cotton, .jersey, .canvas]
    static let coolWeatherFabrics: Set<FashionFabric> = [.wool, .cashmere, .knit, .fleece, .tweed]

    static let structuredFabrics: Set<FashionFabric> = [.leather, .denim, .tweed]
    static let delicateRainRiskFabrics: Set<FashionFabric> = [.suede, .silk]
    static let selectiveShineFabrics: Set<FashionFabric> = [.silk]

    static func stylePersonality(for metadata: FashionItemMetadata) -> Set<StylePersonalityTag> {
        var tags = Set<StylePersonalityTag>()

        for style in metadata.styleTags {
            switch style {
            case .classic: tags.insert(.classic)
            case .minimal: tags.insert(.minimalist)
            case .clean: tags.insert(.clean)
            case .casual: tags.insert(.casual)
            case .elegant: tags.insert(.elegant)
            case .edgy: tags.insert(.edgy)
            case .sporty: tags.insert(.sporty)
            case .relaxed: tags.insert(.relaxed)
            case .statement: tags.insert(.statement)
            case .streetwear, .street: tags.insert(.street)
            case .smartCasual:
                tags.insert(.classic)
                tags.insert(.clean)
            case .romantic:
                tags.insert(.elegant)
            case .preppy:
                tags.insert(.classic)
            case .workwear:
                tags.insert(.casual)
            }
        }

        if metadata.statementLevel == .bold { tags.insert(.statement) }
        if metadata.formality >= .smartCasual { tags.insert(.clean) }
        if tags.isEmpty { tags.insert(.casual) }
        return tags
    }

    static func deriveWeatherContext(from context: FashionEvaluationContext) -> WeatherStyleContext {
        let t = context.temperatureCelsius
        let mood: WeatherMood
        if let t {
            if t < 10 {
                mood = .cold
            } else if t >= 27 {
                mood = .hot
            } else {
                mood = .mild
            }
        } else {
            mood = .clear
        }
        return WeatherStyleContext(
            temperatureCelsius: t,
            rainLikely: context.isRainLikely ?? false,
            mood: (context.isRainLikely ?? false) ? .rainy : mood
        )
    }

    static func inferOccasionLens(from context: FashionEvaluationContext) -> LuckyLookOccasionLens {
        switch context.targetOccasion ?? .everyday {
        case .casual, .sporty:
            return .casual
        case .smartCasual, .businessCasual:
            return .smartCasual
        case .formal, .evening:
            return .formalDinner
        case .vacationBeach:
            return .travel
        case .everyday:
            return .weatherBasedDailyUse
        }
    }
}
