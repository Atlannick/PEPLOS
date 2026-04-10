//
//  FashionTypes.swift
//  PEPLOS
//
//  Core enums and value types for the local fashion knowledge engine.
//  These types are designed to attach to closet items (now or later) and to drive
//  rule-based scoring without any network or backend dependency.
//

import Foundation

// MARK: - Color

/// Canonical wardrobe colors used by the local engine. Each case maps to a hue on the
/// color wheel (when not neutral) so we can evaluate harmony, contrast, and clashes offline.
enum FashionColor: String, CaseIterable, Codable, Hashable, Sendable {
    // Neutrals & near-neutrals (no hue or treated as anchors)
    case white
    case offWhite
    case cream
    case black
    case charcoal
    case gray
    case silver
    case beige
    case taupe
    case brown
    case espresso
    case navy

    // Cool hues
    case skyBlue
    case powderBlue
    case denimBlue
    case cobalt
    case teal
    case mint
    case sage
    case olive
    case forest
    case emerald

    // Warm hues
    case yellow
    case mustard
    case gold
    case peach
    case coral
    case orange
    case rust
    case terracotta
    case red
    case burgundy
    case blush
    case hotPink
    case magenta
    case lavender
    case lilac
    case plum
    case purple

    /// Hue angle in degrees for color-wheel logic; `nil` means neutral / achromatic anchor.
    var hueDegrees: Double? {
        switch self {
        case .white, .offWhite, .cream, .black, .charcoal, .gray, .silver, .beige, .taupe, .brown, .espresso, .navy:
            return nil
        case .skyBlue: return 205
        case .powderBlue: return 210
        case .denimBlue: return 215
        case .cobalt: return 220
        case .teal: return 180
        case .mint: return 160
        case .sage: return 120
        case .olive: return 85
        case .forest: return 145
        case .emerald: return 155
        case .yellow: return 55
        case .mustard: return 48
        case .gold: return 50
        case .peach: return 25
        case .coral: return 12
        case .orange: return 30
        case .rust: return 20
        case .terracotta: return 18
        case .red: return 0
        case .burgundy: return 350
        case .blush: return 350
        case .hotPink: return 330
        case .magenta: return 310
        case .lavender: return 270
        case .lilac: return 285
        case .plum: return 300
        case .purple: return 275
        }
    }

    /// Whether this color acts as a neutral anchor in outfit building.
    var isNeutral: Bool {
        switch self {
        case .white, .offWhite, .cream, .black, .charcoal, .gray, .silver, .beige, .taupe, .brown, .espresso, .navy:
            return true
        default:
            return false
        }
    }

    /// Rough saturation bucket for clash detection (hot colors read as "loud" faster).
    var saturationTier: Int {
        switch self {
        case .red, .orange, .hotPink, .magenta, .coral, .yellow, .gold:
            return 3
        case .mustard, .rust, .terracotta, .burgundy, .emerald, .cobalt, .purple, .plum:
            return 2
        default:
            return 1
        }
    }
}

// MARK: - Fit & silhouette

/// How an item reads on the body; used for loose/tight balance rules.
enum FashionFit: String, CaseIterable, Codable, Hashable, Sendable {
    case slim
    case regular
    case relaxed
    case oversized
}

/// Visual weight of patterns, logos, or color blocking.
enum FashionStatementLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case none
    case subtle
    case bold
}

// MARK: - Formality & warmth

/// Discrete formality steps from very casual to black-tie-adjacent.
enum FashionFormality: Int, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case ultraCasual = 0
    case casual = 1
    case smartCasual = 2
    case businessCasual = 3
    case business = 4
    case formal = 5
    case blackTie = 6

    static func < (lhs: FashionFormality, rhs: FashionFormality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Thermal weight for season and layering checks.
enum FashionWarmth: String, CaseIterable, Codable, Hashable, Sendable {
    case coolLightweight
    case allSeason
    case warmMidweight
    case coldHeavyweight
}

// MARK: - Occasion

/// Life contexts the engine can optimize for. `everyday` is a relaxed default lens.
enum FashionOccasion: String, CaseIterable, Codable, Hashable, Sendable {
    case casual
    case smartCasual
    case businessCasual
    case formal
    case evening
    case sporty
    case vacationBeach
    case everyday
}

// MARK: - Season

enum FashionSeason: String, CaseIterable, Codable, Hashable, Sendable {
    case spring
    case summer
    case autumn
    case winter
}

// MARK: - Wardrobe category (engine)

/// High-level slot in an outfit. Distinct from user-defined `ClothingCategory` names in the closet.
enum FashionItemCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case top
    case bottom
    case dress
    case shoes
    case outerwear
    case accessory
    case hat
    case bag
    case layer // e.g. cardigan, vest worn between top and outerwear
}

// MARK: - Style families

/// Aesthetic tags for coherence and future ranking.
enum FashionStyleTag: String, CaseIterable, Codable, Hashable, Sendable {
    case minimal
    case classic
    case clean
    case casual
    case streetwear
    case street
    case sporty
    case elegant
    case edgy
    case statement
    case smartCasual
    case relaxed
    case romantic
    case preppy
    case workwear
}

// MARK: - Fabric (season hints)

enum FashionFabric: String, CaseIterable, Codable, Hashable, Sendable {
    case cotton
    case linen
    case silk
    case wool
    case cashmere
    case denim
    case leather
    case suede
    case nylon
    case fleece
    case knit
    case tweed
    case canvas
    case jersey
}

// MARK: - Per-item metadata

/// Attachable metadata for a closet item. Persistence can be added later without changing the engine API.
struct FashionItemMetadata: Codable, Hashable, Sendable {
    var category: FashionItemCategory
    var primaryColor: FashionColor
    var secondaryColor: FashionColor?
    var suitableSeasons: Set<FashionSeason>
    var suitableOccasions: Set<FashionOccasion>
    var styleTags: Set<FashionStyleTag>
    var formality: FashionFormality
    var warmth: FashionWarmth
    var fit: FashionFit
    var statementLevel: FashionStatementLevel
    var fabrics: Set<FashionFabric>

    init(
        category: FashionItemCategory,
        primaryColor: FashionColor,
        secondaryColor: FashionColor? = nil,
        suitableSeasons: Set<FashionSeason>,
        suitableOccasions: Set<FashionOccasion>,
        styleTags: Set<FashionStyleTag>,
        formality: FashionFormality,
        warmth: FashionWarmth,
        fit: FashionFit = .regular,
        statementLevel: FashionStatementLevel = .none,
        fabrics: Set<FashionFabric> = []
    ) {
        self.category = category
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.suitableSeasons = suitableSeasons
        self.suitableOccasions = suitableOccasions
        self.styleTags = styleTags
        self.formality = formality
        self.warmth = warmth
        self.fit = fit
        self.statementLevel = statementLevel
        self.fabrics = fabrics
    }
}

/// One engine row: optional stable id (e.g. closet UUID) plus metadata.
struct ScorableFashionItem: Hashable, Sendable {
    var id: UUID?
    var metadata: FashionItemMetadata

    init(id: UUID? = nil, metadata: FashionItemMetadata) {
        self.id = id
        self.metadata = metadata
    }
}

// MARK: - Evaluation context & results

/// Optional lens for outfit rules (target occasion, season, weather, minimum completeness).
struct FashionEvaluationContext: Sendable {
    var targetOccasion: FashionOccasion?
    var targetSeason: FashionSeason?
    /// Current air temperature (°C) when known — used to align warmth and seasonal cues.
    var temperatureCelsius: Double?
    /// True when current conditions suggest rain/wet streets.
    var isRainLikely: Bool?
    /// When true, missing shoes or core coverage is penalized more strongly.
    var strictCompleteness: Bool

    init(
        targetOccasion: FashionOccasion? = nil,
        targetSeason: FashionSeason? = nil,
        temperatureCelsius: Double? = nil,
        isRainLikely: Bool? = nil,
        strictCompleteness: Bool = false
    ) {
        self.targetOccasion = targetOccasion
        self.targetSeason = targetSeason
        self.temperatureCelsius = temperatureCelsius
        self.isRainLikely = isRainLikely
        self.strictCompleteness = strictCompleteness
    }
}

/// Human-readable outfit notes from local rules (no numeric style score).
struct FashionOutfitNarrative: Sendable {
    var summaryLines: [String]
    var strengths: [String]
    var weaknesses: [String]
    /// Fine-grained notes (may overlap with strengths/weaknesses).
    var explanations: [String]
}
