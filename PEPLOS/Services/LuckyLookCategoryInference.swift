//
//  LuckyLookCategoryInference.swift
//  PEPLOS
//
//  Keyword-based closet category → engine slot mapping when `fashionMetadata` and
//  `FashionEngine.inferFashionCategory` do not resolve a category. Expand lists here only.
//

import Foundation

enum LuckyLookCategoryInference {

    /// Maps a user-facing category name (e.g. chip label) to a `FashionItemCategory`.
    /// Checks more specific garment types before generic ones (e.g. dress before top).
    static func inferCategory(fromCategoryName name: String) -> FashionItemCategory {
        let n = normalize(name)

        if matches(n, anyOf: Keywords.dress) { return .dress }
        if matches(n, anyOf: Keywords.shoes) { return .shoes }
        if matches(n, anyOf: Keywords.bottoms) { return .bottom }
        if matches(n, anyOf: Keywords.outerwear) { return .outerwear }
        if matches(n, anyOf: Keywords.hat) { return .hat }
        if matches(n, anyOf: Keywords.accessory) { return .accessory }
        if matches(n, anyOf: Keywords.bag) { return .bag }
        if matches(n, anyOf: Keywords.tops) { return .top }

        return .top
    }

    private static func normalize(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func matches(_ normalized: String, anyOf terms: [String]) -> Bool {
        for t in terms {
            if normalized.contains(t) { return true }
        }
        return false
    }

    // MARK: - Keyword lists (expand here)

    private enum Keywords {
        static let dress: [String] = [
            "dress", "gown", "jumpsuit", "romper", "playsuit",
        ]

        static let tops: [String] = [
            "top", "shirt", "tshirt", "t shirt", "t-shirt", "tee", "blouse", "hoodie", "sweater",
            "pullover", "cardigan", "tank", "camisole", "polo", "henley", "crop top", "bodysuit",
            "knit top", "long sleeve", "sweatshirt", "tunic",
        ]

        static let bottoms: [String] = [
            "bottom", "pant", "trouser", "jean", "denim", "short", "skirt", "legging", "chino",
            "cargo", "jogger", "sweatpant",
        ]

        static let shoes: [String] = [
            "shoe", "sneaker", "boot", "heel", "loafer", "sandal", "slipper", "oxford", "mule",
            "espadrille", "flat", "ankle boot", "trainer",
        ]

        static let outerwear: [String] = [
            "outerwear", "jacket", "coat", "blazer", "parka", "anorak", "windbreaker", "bomber",
            "trench", "puffer", "vest", "gilet", "overcoat", "peacoat",
        ]

        static let hat: [String] = [
            "hat", "cap", "beanie", "beret", "fedora", "bucket hat",
        ]

        static let accessory: [String] = [
            "accessor", "scarf", "belt", "watch", "jewelry", "jewellery", "necklace", "bracelet",
            "earring", "ring", "sunglass", "glove", "tie", "bow tie", "pocket square",
        ]

        static let bag: [String] = [
            "bag", "purse", "tote", "backpack", "clutch", "wallet",
        ]
    }
}
