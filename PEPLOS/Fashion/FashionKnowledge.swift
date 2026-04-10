//
//  FashionKnowledge.swift
//  PEPLOS
//
//  Curated offline styling knowledge: color relationships, occasions, seasons,
//  category grammar, and balance heuristics. This is reference data for rules —
//  not trend data or brand-specific rules.
//

import Foundation

// MARK: - Color knowledge

/// Static color-theory and wardrobe-building facts used by `FashionRules` and outfit narrative.
enum FashionKnowledge {

    // MARK: Neutrals

    /// Colors treated as outfit "anchors" that pair broadly.
    static let neutralColors: Set<FashionColor> = [
        .white, .offWhite, .cream, .black, .charcoal, .gray, .silver,
        .beige, .taupe, .brown, .espresso, .navy,
    ]

    // MARK: Safe & classic combinations

    /// Pairs that almost always read as intentional and polished (order-independent).
    static let strongClassicPairs: Set<UnorderedPair<FashionColor>> = [
        .init(.navy, .white),
        .init(.navy, .beige),
        .init(.black, .white),
        .init(.charcoal, .white),
        .init(.gray, .white),
        .init(.denimBlue, .white),
        .init(.denimBlue, .cream),
        .init(.brown, .navy),
        .init(.brown, .cream),
        .init(.espresso, .cream),
        .init(.burgundy, .navy),
        .init(.forest, .beige),
        .init(.olive, .cream),
        .init(.brown, .charcoal),
    ]

    /// Low-risk pairings: neutrals with soft chroma, or neutral + single accent families.
    static let safeUniversalPairs: Set<UnorderedPair<FashionColor>> = strongClassicPairs.union([
        .init(.blush, .gray),
        .init(.powderBlue, .gray),
        .init(.sage, .white),
        .init(.lavender, .gray),
        .init(.teal, .cream),
        .init(.mint, .white),
    ])

    // MARK: Risk & clash heuristics

    /// Combinations that often fight each other when both are dominant (not forbidden — weighted down).
    static let commonlyClashingPairs: Set<UnorderedPair<FashionColor>> = [
        .init(.red, .emerald),
        .init(.orange, .magenta),
        .init(.hotPink, .red),
        .init(.yellow, .purple),
    ]

    // MARK: Seasonal color tendencies

    static let springFriendlyColors: Set<FashionColor> = [
        .blush, .lavender, .lilac, .mint, .powderBlue, .sage, .cream, .white, .yellow, .peach,
    ]

    static let summerFriendlyColors: Set<FashionColor> = [
        .white, .offWhite, .skyBlue, .denimBlue, .coral, .teal, .mint, .yellow, .beige,
    ]

    static let autumnFriendlyColors: Set<FashionColor> = [
        .rust, .terracotta, .mustard, .olive, .burgundy, .brown, .espresso, .forest, .cream, .charcoal,
    ]

    static let winterFriendlyColors: Set<FashionColor> = [
        .black, .charcoal, .navy, .burgundy, .plum, .forest, .emerald, .gray, .white,
    ]

    static func seasonalPalette(_ season: FashionSeason) -> Set<FashionColor> {
        switch season {
        case .spring: return springFriendlyColors
        case .summer: return summerFriendlyColors
        case .autumn: return autumnFriendlyColors
        case .winter: return winterFriendlyColors
        }
    }

    // MARK: Occasion profiles

    struct OccasionProfile: Sendable {
        var idealFormalityRange: ClosedRange<FashionFormality>
        var preferredCategories: Set<FashionItemCategory>
        var discouragedCategories: Set<FashionItemCategory>
        var typicalFootwearFormality: ClosedRange<FashionFormality>
        var notes: [String]
    }

    static func occasionProfile(_ o: FashionOccasion) -> OccasionProfile {
        switch o {
        case .casual:
            return OccasionProfile(
                idealFormalityRange: .ultraCasual ... .casual,
                preferredCategories: [.top, .bottom, .shoes, .accessory],
                discouragedCategories: [],
                typicalFootwearFormality: .ultraCasual ... .casual,
                notes: [
                    "Denim, tees, relaxed knits, and sneakers are natural fits.",
                    "Keep accessories minimal unless adding a clear focal point.",
                ]
            )
        case .smartCasual:
            return OccasionProfile(
                idealFormalityRange: .casual ... .smartCasual,
                preferredCategories: [.top, .bottom, .shoes, .outerwear, .bag, .accessory],
                discouragedCategories: [],
                typicalFootwearFormality: .casual ... .smartCasual,
                notes: [
                    "Polished separates: collared shirts, dark denim or chinos, loafers or clean sneakers.",
                    "One refined piece (blazer, leather shoe, structured bag) upgrades the whole look.",
                ]
            )
        case .businessCasual:
            return OccasionProfile(
                idealFormalityRange: .smartCasual ... .businessCasual,
                preferredCategories: [.top, .bottom, .shoes, .outerwear, .bag],
                discouragedCategories: [],
                typicalFootwearFormality: .smartCasual ... .business,
                notes: [
                    "Tailored trousers, knit or woven tops, blazers optional but welcome.",
                    "Avoid loud logos; keep color story restrained.",
                ]
            )
        case .formal:
            return OccasionProfile(
                idealFormalityRange: .business ... .formal,
                preferredCategories: [.top, .bottom, .dress, .shoes, .outerwear, .accessory],
                discouragedCategories: [],
                typicalFootwearFormality: .business ... .formal,
                notes: [
                    "Suits, dress shirts, tailored dresses, leather dress shoes.",
                    "Outerwear should be structured (wool coat, tailored overcoat).",
                ]
            )
        case .evening:
            return OccasionProfile(
                idealFormalityRange: .smartCasual ... .blackTie,
                preferredCategories: [.dress, .top, .bottom, .shoes, .accessory, .outerwear],
                discouragedCategories: [],
                typicalFootwearFormality: .smartCasual ... .formal,
                notes: [
                    "Deeper colors, refined fabrics, optional subtle shine (silk, satin accents).",
                    "Statement accessories work best as a single hero piece.",
                ]
            )
        case .sporty:
            return OccasionProfile(
                idealFormalityRange: .ultraCasual ... .casual,
                preferredCategories: [.top, .bottom, .shoes, .accessory, .hat],
                discouragedCategories: [.bag], // optional — soft penalty only
                typicalFootwearFormality: .ultraCasual ... .casual,
                notes: [
                    "Technical knits, joggers, trainers, caps; prioritize movement and breathability.",
                    "Keep layering light unless weather demands otherwise.",
                ]
            )
        case .vacationBeach:
            return OccasionProfile(
                idealFormalityRange: .ultraCasual ... .smartCasual,
                preferredCategories: [.top, .bottom, .dress, .shoes, .hat, .accessory, .bag],
                discouragedCategories: [],
                typicalFootwearFormality: .ultraCasual ... .casual,
                notes: [
                    "Breathable fabrics, sun coverage, sandals or espadrilles, easy bags.",
                    "Brights and whites feel at home; add one anchor neutral.",
                ]
            )
        case .everyday:
            return OccasionProfile(
                idealFormalityRange: .casual ... .smartCasual,
                preferredCategories: [.top, .bottom, .shoes, .outerwear, .accessory],
                discouragedCategories: [],
                typicalFootwearFormality: .casual ... .smartCasual,
                notes: [
                    "Versatile separates that transition across errands and social stops.",
                    "Neutrals plus one accent color is a reliable default.",
                ]
            )
        }
    }

    // MARK: Season profiles

    struct SeasonProfile: Sendable {
        var favoredColors: Set<FashionColor>
        var commonFabrics: Set<FashionFabric>
        var typicalItems: Set<FashionItemCategory>
        var layeringExpectation: LayeringExpectation
        var notes: [String]
    }

    enum LayeringExpectation: String, Sendable {
        case light
        case moderate
        case heavy
    }

    static func seasonProfile(_ s: FashionSeason) -> SeasonProfile {
        switch s {
        case .spring:
            return SeasonProfile(
                favoredColors: springFriendlyColors,
                commonFabrics: [.cotton, .knit, .silk, .denim, .jersey],
                typicalItems: [.top, .bottom, .shoes, .layer, .outerwear, .accessory],
                layeringExpectation: .moderate,
                notes: [
                    "Transitional layering: light jackets, trenches, cardigans.",
                    "Pastels and fresh greens read seasonal without feeling costumey.",
                ]
            )
        case .summer:
            return SeasonProfile(
                favoredColors: summerFriendlyColors,
                commonFabrics: [.linen, .cotton, .jersey, .silk, .canvas],
                typicalItems: [.top, .bottom, .dress, .shoes, .hat, .bag],
                layeringExpectation: .light,
                notes: [
                    "Prioritize breathability; minimize heavy layers unless evenings cool down.",
                    "Lighter palette keeps outfits feeling cool and clean.",
                ]
            )
        case .autumn:
            return SeasonProfile(
                favoredColors: autumnFriendlyColors,
                commonFabrics: [.wool, .knit, .denim, .suede, .leather, .tweed],
                typicalItems: [.top, .bottom, .shoes, .outerwear, .layer, .accessory],
                layeringExpectation: .moderate,
                notes: [
                    "Earth tones and richer textures signal the season.",
                    "Boots and midweight knits are natural pairings.",
                ]
            )
        case .winter:
            return SeasonProfile(
                favoredColors: winterFriendlyColors,
                commonFabrics: [.wool, .cashmere, .fleece, .tweed, .leather],
                typicalItems: [.top, .bottom, .shoes, .outerwear, .accessory, .hat, .layer],
                layeringExpectation: .heavy,
                notes: [
                    "Insulation and wind protection matter; outerwear anchors the look.",
                    "Deep neutrals and jewel tones feel cohesive in cold light.",
                ]
            )
        }
    }

    // MARK: Category pairing

    /// Which categories commonly pair in a complete outfit (undirected edges).
    static let naturalCategoryPairs: Set<UnorderedCategoryPair> = [
        .init(.top, .bottom),
        .init(.dress, .shoes),
        .init(.top, .layer),
        .init(.layer, .outerwear),
        .init(.bottom, .shoes),
        .init(.top, .shoes), // color/formality bridge
        .init(.outerwear, .bottom),
        .init(.bag, .shoes),
        .init(.hat, .outerwear),
    ]

    /// Categories that often define formality "floor" for the outfit.
    static let formalityAnchorCategories: Set<FashionItemCategory> = [.shoes, .outerwear, .dress]

    // MARK: High-contrast & low-risk (extended)

    /// Intentionally bold but wearable pairings (neutral + chromatic or strong light/dark).
    static let highContrastPairs: Set<UnorderedPair<FashionColor>> = [
        .init(.black, .white),
        .init(.charcoal, .cream),
        .init(.navy, .white),
        .init(.espresso, .cream),
        .init(.black, .coral),
        .init(.navy, .mustard),
        .init(.gray, .yellow),
        .init(.white, .cobalt),
    ]

    /// Trios that stay calm: neutrals + one accent family (reference for future triad scoring).
    static let lowRiskTriads: [[FashionColor]] = [
        [.navy, .white, .denimBlue],
        [.black, .gray, .white],
        [.beige, .white, .olive],
        [.charcoal, .blush, .cream],
        [.espresso, .cream, .sage],
    ]

    /// Style-tag affinities: pairs that often co-occur in coherent wardrobes.
    static let styleTagAffinities: Set<UnorderedPair<FashionStyleTag>> = [
        .init(.minimal, .classic),
        .init(.classic, .elegant),
        .init(.streetwear, .sporty),
        .init(.smartCasual, .classic),
        .init(.relaxed, .minimal),
        .init(.preppy, .classic),
    ]
}

// MARK: - Small helpers

/// Order-independent pair for colors.
struct UnorderedPair<T: Hashable>: Hashable, Sendable {
    let a: T
    let b: T

    init(_ a: T, _ b: T) {
        let x = String(describing: a)
        let y = String(describing: b)
        if x <= y {
            self.a = a
            self.b = b
        } else {
            self.a = b
            self.b = a
        }
    }
}

struct UnorderedCategoryPair: Hashable, Sendable {
    let a: FashionItemCategory
    let b: FashionItemCategory

    init(_ a: FashionItemCategory, _ b: FashionItemCategory) {
        if a.rawValue <= b.rawValue {
            self.a = a
            self.b = b
        } else {
            self.a = b
            self.b = a
        }
    }
}
