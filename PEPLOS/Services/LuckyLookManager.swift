//
//  LuckyLookManager.swift
//  PEPLOS
//
//  Generates Lucky Look outfits from closet items using FashionEngine ranking with lightweight
//  candidate sampling for performance.
//

import Combine
import Foundation

// MARK: - Models

/// Persisted snapshot of the latest Lucky Look result.
struct LuckyLookSnapshot: Equatable, Codable, Identifiable {
    var generatedAt: Date
    var itemIds: [UUID]
    /// Primary line for Home / result UI (composed from engine + weather).
    var mainExplanation: String
    /// Strengths for “Why this works” (persisted for offline display).
    var strengths: [String]

    var id: String {
        itemIds.map(\.uuidString).sorted().joined() + "-\(generatedAt.timeIntervalSince1970)"
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt, itemIds, mainExplanation, strengths, explanationLine
    }

    init(generatedAt: Date, itemIds: [UUID], mainExplanation: String, strengths: [String]) {
        self.generatedAt = generatedAt
        self.itemIds = itemIds
        self.mainExplanation = mainExplanation
        self.strengths = strengths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        itemIds = try c.decode([UUID].self, forKey: .itemIds)
        if let m = try c.decodeIfPresent(String.self, forKey: .mainExplanation) {
            mainExplanation = m
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .explanationLine) {
            mainExplanation = legacy
        } else {
            mainExplanation = ""
        }
        strengths = try c.decodeIfPresent([String].self, forKey: .strengths) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(generatedAt, forKey: .generatedAt)
        try c.encode(itemIds, forKey: .itemIds)
        try c.encode(mainExplanation, forKey: .mainExplanation)
        try c.encode(strengths, forKey: .strengths)
    }
}

enum LuckyLookError: Equatable, LocalizedError {
    case emptyCloset
    case noPhotos
    case cannotBuildCoreOutfit
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .emptyCloset: return "No clothing items in the closet."
        case .noPhotos: return "Add photos to your items for Lucky Look."
        case .cannotBuildCoreOutfit:
            return "Add more clothing items to generate a Lucky Look."
        case .generationFailed: return "Could not build an outfit right now."
        }
    }
}

/// One generated outfit proposal (in-memory).
struct LuckyLookGeneration {
    var itemIds: [UUID]
    var narrative: FashionOutfitNarrative
    var context: FashionEvaluationContext
}

// MARK: - Manager

@MainActor
final class LuckyLookManager: ObservableObject {
    private let defaults: UserDefaults

    /// Latest valid snapshot for the Home card (refreshed from persistence + closet validation).
    @Published private(set) var activeSnapshot: LuckyLookSnapshot?

    /// When set, matches `LuckyLookSnapshot.id` for the look the user already saved to “Your Outfits”.
    @Published private(set) var savedLuckyLookSnapshotId: String?

    private enum Keys {
        static let snapshot = "peplos.luckyLook.snapshot.v1"
        static let savedSnapshotId = "peplos.luckyLook.savedSnapshotId.v1"
        static let recentHistory = "peplos.luckyLook.recentHistory.v1"
        static let generatedCount = "peplos.luckyLook.generatedCount.v1"
    }

    /// Caps combinatorial work — random samples within buckets.
    private let maxCandidateEvaluations = 96
    private let maxBucketSample = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.savedLuckyLookSnapshotId = defaults.string(forKey: Keys.savedSnapshotId)
    }

    /// Reload snapshot from disk after closet changes (call from Home `onAppear`).
    func refreshSnapshot(closet: ClosetStore) {
        activeSnapshot = getTodaysLuckyLook(closet: closet)
    }

    // MARK: - Public API

    func canGenerateNewLuckyLook(now: Date = .init()) -> Bool {
        true
    }

    func timeUntilNextLuckyLookAvailable(now: Date = .init()) -> TimeInterval? {
        nil
    }

    /// Total number of Lucky Looks generated on this device.
    func totalGeneratedLooks() -> Int {
        defaults.integer(forKey: Keys.generatedCount)
    }

    /// Builds `ScorableFashionItem` rows for `FashionEngine` (same rules as generation). Returns `nil` if any id is missing or lacks a photo.
    func scorableItems(for itemIds: [UUID], closet: ClosetStore) -> [ScorableFashionItem]? {
        guard !itemIds.isEmpty else { return nil }
        var rows: [ScorableFashionItem] = []
        rows.reserveCapacity(itemIds.count)
        for id in itemIds {
            guard let item = closet.items.first(where: { $0.id == id }),
                  item.hasUploadedPhoto,
                  let name = closet.categoryName(forItemId: item.id)
            else { return nil }
            let slot = Self.resolvedSlot(item: item, categoryName: name)
            rows.append(Self.scorableItem(item: item, categoryName: name, slot: slot))
        }
        return rows
    }

    /// Active snapshot if items still exist in the closet.
    func getTodaysLuckyLook(closet: ClosetStore, now: Date = .init()) -> LuckyLookSnapshot? {
        guard let data = defaults.data(forKey: Keys.snapshot),
              let snap = try? JSONDecoder().decode(LuckyLookSnapshot.self, from: data)
        else { return nil }

        let validIds = snap.itemIds.filter { id in
            closet.items.contains { $0.id == id && $0.hasUploadedPhoto }
        }
        guard validIds.count == snap.itemIds.count, !validIds.isEmpty else {
            clearPersisted()
            activeSnapshot = nil
            return nil
        }
        pruneSavedIdIfStale(for: snap)
        return snap
    }

    /// Persists the generation and updates `activeSnapshot`. Resets “saved” until the user saves again.
    func persist(_ generation: LuckyLookGeneration) {
        let line = Self.composeExplanation(narrative: generation.narrative, context: generation.context)
        let strengthLines = Array(generation.narrative.strengths.prefix(8))
        let now = Date()
        let snap = LuckyLookSnapshot(
            generatedAt: now,
            itemIds: generation.itemIds,
            mainExplanation: line,
            strengths: strengthLines
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: Keys.snapshot)
        }
        defaults.set(defaults.integer(forKey: Keys.generatedCount) + 1, forKey: Keys.generatedCount)
        appendRecentLook(itemIds: generation.itemIds, date: now)
        defaults.removeObject(forKey: Keys.savedSnapshotId)
        savedLuckyLookSnapshotId = nil
        activeSnapshot = snap
    }

    /// Call after adding this Lucky Look to `OutfitStore` so “Save Outfit” stays hidden for this look.
    func markLuckyLookOutfitSaved(snapshotId: String) {
        defaults.set(snapshotId, forKey: Keys.savedSnapshotId)
        savedLuckyLookSnapshotId = snapshotId
    }

    /// `false` once this snapshot has been saved; `true` until then (including across app launches).
    func shouldShowSaveOutfit(for snapshot: LuckyLookSnapshot) -> Bool {
        guard let saved = savedLuckyLookSnapshotId else { return true }
        return saved != snapshot.id
    }

    func clearPersisted() {
        defaults.removeObject(forKey: Keys.snapshot)
        defaults.removeObject(forKey: Keys.savedSnapshotId)
        defaults.removeObject(forKey: Keys.recentHistory)
        defaults.removeObject(forKey: Keys.generatedCount)
        activeSnapshot = nil
        savedLuckyLookSnapshotId = nil
    }

    private func recentHistory() -> [LuckyLookRecencyRecord] {
        guard let data = defaults.data(forKey: Keys.recentHistory),
              let records = try? JSONDecoder().decode([LuckyLookRecencyRecord].self, from: data)
        else {
            return []
        }
        return records
    }

    private func appendRecentLook(itemIds: [UUID], date: Date) {
        var records = recentHistory()
        let sorted = itemIds.sorted { $0.uuidString < $1.uuidString }
        records.insert(
            LuckyLookRecencyRecord(generatedAt: date, sortedItemIds: sorted),
            at: 0
        )
        records = Array(records.prefix(30))
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.recentHistory)
        }
    }

    /// Drops saved state if it refers to a different snapshot than the one on disk (e.g. after reinstall edge cases).
    private func pruneSavedIdIfStale(for snap: LuckyLookSnapshot) {
        guard let saved = savedLuckyLookSnapshotId, saved != snap.id else { return }
        defaults.removeObject(forKey: Keys.savedSnapshotId)
        savedLuckyLookSnapshotId = nil
    }

    /// Builds evaluation context from weather + calendar season. Default occasion: casual / everyday.
    func makeEvaluationContext(weather: StylistWeatherController, now: Date = .init()) -> FashionEvaluationContext {
        let weatherSymbol = weather.weatherSymbolName.lowercased()
        let rainLikely = (
            weatherSymbol.contains("rain")
                || weatherSymbol.contains("drizzle")
                || weatherSymbol.contains("sleet")
                || weatherSymbol.contains("storm")
        )
        return FashionEvaluationContext(
            targetOccasion: .everyday,
            targetSeason: FashionRules.seasonForDate(now),
            temperatureCelsius: weather.temperatureCelsius,
            isRainLikely: rainLikely,
            strictCompleteness: false
        )
    }

    /// Picks an outfit from sampled candidates using pairwise ranking, then attaches narrative notes.
    func generateLuckyLook(
        closet: ClosetStore,
        context: FashionEvaluationContext
    ) -> Result<LuckyLookGeneration, LuckyLookError> {
        let withPhotos = closet.items.filter { $0.hasUploadedPhoto }
        if closet.items.isEmpty { return .failure(.emptyCloset) }
        if withPhotos.isEmpty { return .failure(.noPhotos) }

        let buckets = Self.classifyItems(withPhotos, closet: closet)
        guard buckets.canGenerateValidCoreOutfit else { return .failure(.cannotBuildCoreOutfit) }

        let canDressCore = buckets.hasDressCore
        let canTopBottomShoeCore = buckets.hasTopBottomShoeCore

        var candidates: [[ScorableFashionItem]] = []
        var seen = Set<String>()

        func appendUnique(_ rows: [ScorableFashionItem]) {
            let key = rows.compactMap(\.id).map(\.uuidString).sorted().joined(separator: "|")
            guard seen.insert(key).inserted else { return }
            candidates.append(rows)
        }

        // Option B: dress + shoes (+ optional only — never replaces core)
        if canDressCore {
            let dresses = Self.sample(buckets.dresses, max: maxBucketSample)
            let shoesD = Self.sample(buckets.shoes, max: maxBucketSample)
            dressLoop: for d in dresses {
                for s in shoesD {
                    var base = [d, s]
                    base = Self.attachOptionalPieces(
                        to: base,
                        outerwear: buckets.outerwear,
                        accessories: buckets.accessories,
                        hats: buckets.hats,
                        context: context
                    )
                    appendUnique(base)
                    if candidates.count >= maxCandidateEvaluations { break dressLoop }
                }
            }
        }

        // Option A: top + bottom + shoes (+ optional)
        if canTopBottomShoeCore {
            let tops = Self.sample(buckets.tops, max: maxBucketSample)
            let bottoms = Self.sample(buckets.bottoms, max: maxBucketSample)
            let shoes = Self.sample(buckets.shoes, max: maxBucketSample)
            tbsLoop: for t in tops {
                for b in bottoms {
                    for s in shoes {
                        var base = [t, b, s]
                        base = Self.attachOptionalPieces(
                            to: base,
                            outerwear: buckets.outerwear,
                            accessories: buckets.accessories,
                            hats: buckets.hats,
                            context: context
                        )
                        appendUnique(base)
                        if candidates.count >= maxCandidateEvaluations { break tbsLoop }
                    }
                }
            }
        }

        if candidates.count < 24 {
            Self.randomFill(
                buckets: buckets,
                context: context,
                appendUnique: appendUnique,
                maxTotal: maxCandidateEvaluations,
                currentCount: { candidates.count }
            )
        }

        guard !candidates.isEmpty else { return .failure(.generationFailed) }

        let ranked = FashionKnowledgeEngine.rankCandidates(
            candidates: candidates,
            context: context,
            recents: recentHistory()
        )
        guard let winner = ranked.first else { return .failure(.generationFailed) }
        let winnerItems = winner.items
        let winnerNarrative = FashionOutfitNarrative(
            summaryLines: [winner.explanation],
            strengths: winner.strengths,
            weaknesses: [],
            explanations: winner.strengths
        )
        let ids = winnerItems.compactMap(\.id)
        guard ids.count == winnerItems.count else { return .failure(.generationFailed) }

        return .success(LuckyLookGeneration(itemIds: ids, narrative: winnerNarrative, context: context))
    }

    // MARK: - Explanation

    static func composeExplanation(narrative: FashionOutfitNarrative, context: FashionEvaluationContext) -> String {
        let weatherFrag = weatherFragment(celsius: context.temperatureCelsius, season: context.targetSeason)
        if let first = narrative.strengths.first {
            let trimmed = first.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(".") {
                return "\(trimmed.dropLast()) \(weatherFrag)"
            }
            return "\(trimmed). \(weatherFrag)"
        }
        if let line = narrative.summaryLines.first {
            return "\(line) \(weatherFragment(celsius: context.temperatureCelsius, season: context.targetSeason))"
        }
        return "Balanced casual outfit \(weatherFrag.lowercased())."
    }

    private static func weatherFragment(celsius: Double?, season: FashionSeason?) -> String {
        let seasonWord: String
        if let s = season {
            switch s {
            case .spring: seasonWord = "this spring"
            case .summer: seasonWord = "warm weather"
            case .autumn: seasonWord = "cooler days"
            case .winter: seasonWord = "cold weather"
            }
        } else {
            seasonWord = "today"
        }
        guard let c = celsius else {
            return "suitable for \(seasonWord)."
        }
        switch c {
        case ..<10:
            return "suited to today’s cold temperature."
        case 10..<18:
            return "comfortable for today’s mild temperature."
        case 18..<26:
            return "right for today’s pleasant warmth."
        default:
            return "great for hot weather today."
        }
    }

    // MARK: - Buckets

    private struct ItemBuckets {
        var tops: [ScorableFashionItem] = []
        var bottoms: [ScorableFashionItem] = []
        var dresses: [ScorableFashionItem] = []
        var shoes: [ScorableFashionItem] = []
        var outerwear: [ScorableFashionItem] = []
        var accessories: [ScorableFashionItem] = []
        var hats: [ScorableFashionItem] = []

        /// Option B: dress + shoes (shoes required).
        var hasDressCore: Bool {
            !dresses.isEmpty && !shoes.isEmpty
        }

        /// Option A: top + bottom + shoes.
        var hasTopBottomShoeCore: Bool {
            !tops.isEmpty && !bottoms.isEmpty && !shoes.isEmpty
        }

        /// Valid when we have shoes and at least one full core path (never outerwear-only, etc.).
        var canGenerateValidCoreOutfit: Bool {
            !shoes.isEmpty && (hasDressCore || hasTopBottomShoeCore)
        }
    }

    private static func classifyItems(_ items: [ClothingItem], closet: ClosetStore) -> ItemBuckets {
        var b = ItemBuckets()
        for item in items {
            guard let name = closet.categoryName(forItemId: item.id) else { continue }
            let slot = resolvedSlot(item: item, categoryName: name)
            let sc = scorableItem(item: item, categoryName: name, slot: slot)
            switch slot {
            case .top, .layer:
                b.tops.append(sc)
            case .bottom:
                b.bottoms.append(sc)
            case .dress:
                b.dresses.append(sc)
            case .shoes:
                b.shoes.append(sc)
            case .outerwear:
                b.outerwear.append(sc)
            case .hat:
                b.hats.append(sc)
            case .accessory, .bag:
                b.accessories.append(sc)
            }
        }
        return b
    }

    /// `fashionMetadata` → `FashionEngine` → keyword lists in `LuckyLookCategoryInference`.
    private static func resolvedSlot(item: ClothingItem, categoryName: String) -> FashionItemCategory {
        if let m = item.fashionMetadata { return m.category }
        if let inferred = FashionEngine.inferFashionCategory(fromClosetCategoryName: categoryName) {
            return inferred
        }
        return LuckyLookCategoryInference.inferCategory(fromCategoryName: categoryName)
    }

    private static func scorableItem(item: ClothingItem, categoryName: String, slot: FashionItemCategory) -> ScorableFashionItem {
        if let m = item.fashionMetadata {
            return ScorableFashionItem(id: item.id, metadata: m)
        }
        return ScorableFashionItem(id: item.id, metadata: defaultMetadata(slot: slot, categoryName: categoryName))
    }

    private static func defaultMetadata(slot: FashionItemCategory, categoryName: String) -> FashionItemMetadata {
        let n = categoryName.lowercased()
        let warmth: FashionWarmth = {
            if n.contains("outer") || n.contains("coat") || n.contains("jacket") || n.contains("sweater") || n.contains("fleece") {
                return .warmMidweight
            }
            if n.contains("short") || n.contains("tank") || n.contains("sandal") {
                return .coolLightweight
            }
            return .allSeason
        }()

        let seasons = Set(FashionSeason.allCases)
        let occasions: Set<FashionOccasion> = [.casual, .everyday]

        return FashionItemMetadata(
            category: slot,
            primaryColor: .gray,
            secondaryColor: nil,
            suitableSeasons: seasons,
            suitableOccasions: occasions,
            styleTags: [.relaxed, .classic],
            formality: .casual,
            warmth: warmth,
            fit: .regular,
            statementLevel: .none,
            fabrics: []
        )
    }

    // MARK: - Optional pieces

    private static func attachOptionalPieces(
        to base: [ScorableFashionItem],
        outerwear: [ScorableFashionItem],
        accessories: [ScorableFashionItem],
        hats: [ScorableFashionItem],
        context: FashionEvaluationContext
    ) -> [ScorableFashionItem] {
        var row = base
        if let c = context.temperatureCelsius, c < 14, let o = outerwear.randomElement() {
            row.append(o)
        } else if Double.random(in: 0...1) < 0.22, let o = outerwear.randomElement() {
            row.append(o)
        }
        if Double.random(in: 0...1) < 0.18, let a = accessories.randomElement() {
            row.append(a)
        }
        if Double.random(in: 0...1) < 0.1, let h = hats.randomElement() {
            row.append(h)
        }
        return row
    }

    private static func randomFill(
        buckets: ItemBuckets,
        context: FashionEvaluationContext,
        appendUnique: ([ScorableFashionItem]) -> Void,
        maxTotal: Int,
        currentCount: () -> Int
    ) {
        var attempts = 0
        while currentCount() < maxTotal, attempts < 200 {
            attempts += 1
            if buckets.hasDressCore, let d = buckets.dresses.randomElement(), let s = buckets.shoes.randomElement() {
                var row = [d, s]
                row = attachOptionalPieces(
                    to: row,
                    outerwear: buckets.outerwear,
                    accessories: buckets.accessories,
                    hats: buckets.hats,
                    context: context
                )
                appendUnique(row)
            }
            if buckets.hasTopBottomShoeCore,
               let t = buckets.tops.randomElement(),
               let b = buckets.bottoms.randomElement(),
               let s = buckets.shoes.randomElement() {
                var row = [t, b, s]
                row = attachOptionalPieces(
                    to: row,
                    outerwear: buckets.outerwear,
                    accessories: buckets.accessories,
                    hats: buckets.hats,
                    context: context
                )
                appendUnique(row)
            }
        }
    }

    private static func sample(_ items: [ScorableFashionItem], max: Int) -> [ScorableFashionItem] {
        guard items.count > max else { return items }
        return Array(items.shuffled().prefix(max))
    }
}
