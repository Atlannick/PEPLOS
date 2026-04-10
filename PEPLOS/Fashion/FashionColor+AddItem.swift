//
//  FashionColor+AddItem.swift
//  PEPLOS
//
//  Curated palette and display labels for the Add Item metadata flow.
//

import SwiftUI

extension FashionColor {
    /// Simplified wardrobe palette for manual selection and color detection mapping.
    static let addItemPalette: [FashionColor] = [
        .black, .white, .charcoal, .gray, .silver, .cream, .offWhite, .beige, .taupe,
        .brown, .espresso, .navy, .denimBlue, .cobalt, .skyBlue,
        .red, .burgundy, .blush, .hotPink,
        .forest, .emerald, .olive, .sage, .mint,
        .yellow, .mustard, .orange, .coral,
        .purple, .lavender, .plum,
    ]

    /// Settings → Favorite Colors (multi-select; biases future outfit generation).
    static let settingsFavoritePalette: [FashionColor] = [
        .black, .white, .beige, .denimBlue, .navy, .gray, .brown, .forest, .olive,
        .red, .hotPink, .yellow, .purple, .orange,
    ]

    /// Short label for chips (user-facing).
    var addItemDisplayName: String {
        switch self {
        case .denimBlue: return "Blue"
        case .skyBlue: return "Sky Blue"
        case .hotPink: return "Pink"
        case .blush: return "Blush"
        case .offWhite: return "Off White"
        case .forest: return "Green"
        case .emerald: return "Emerald"
        case .sage: return "Sage"
        case .mustard: return "Mustard"
        case .coral: return "Coral"
        case .burgundy: return "Burgundy"
        default:
            return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// Approximate sRGB (0...1) for distance-based matching from photos.
    var representativeSRGB: (Double, Double, Double) {
        switch self {
        case .white: return (0.98, 0.98, 0.98)
        case .offWhite: return (0.96, 0.95, 0.92)
        case .cream: return (0.96, 0.94, 0.86)
        case .black: return (0.06, 0.06, 0.07)
        case .charcoal: return (0.22, 0.23, 0.25)
        case .gray: return (0.55, 0.56, 0.58)
        case .silver: return (0.78, 0.79, 0.81)
        case .beige: return (0.86, 0.80, 0.72)
        case .taupe: return (0.62, 0.57, 0.52)
        case .brown: return (0.45, 0.33, 0.25)
        case .espresso: return (0.28, 0.20, 0.16)
        case .navy: return (0.12, 0.18, 0.35)
        case .skyBlue: return (0.55, 0.75, 0.92)
        case .powderBlue: return (0.72, 0.82, 0.90)
        case .denimBlue: return (0.25, 0.38, 0.58)
        case .cobalt: return (0.18, 0.35, 0.72)
        case .teal: return (0.18, 0.52, 0.52)
        case .mint: return (0.65, 0.88, 0.78)
        case .sage: return (0.55, 0.65, 0.55)
        case .olive: return (0.45, 0.48, 0.28)
        case .forest: return (0.18, 0.38, 0.28)
        case .emerald: return (0.12, 0.55, 0.42)
        case .yellow: return (0.96, 0.86, 0.22)
        case .mustard: return (0.78, 0.62, 0.18)
        case .gold: return (0.88, 0.72, 0.28)
        case .peach: return (0.96, 0.78, 0.68)
        case .coral: return (0.95, 0.48, 0.42)
        case .orange: return (0.95, 0.55, 0.18)
        case .rust: return (0.68, 0.35, 0.22)
        case .terracotta: return (0.78, 0.42, 0.32)
        case .red: return (0.82, 0.18, 0.18)
        case .burgundy: return (0.48, 0.14, 0.18)
        case .blush: return (0.92, 0.68, 0.72)
        case .hotPink: return (0.95, 0.35, 0.58)
        case .magenta: return (0.78, 0.22, 0.55)
        case .lavender: return (0.78, 0.72, 0.88)
        case .lilac: return (0.82, 0.68, 0.86)
        case .plum: return (0.42, 0.22, 0.38)
        case .purple: return (0.48, 0.28, 0.62)
        }
    }

    /// SwiftUI color for the small swatch in chips.
    var addItemSwatchColor: Color {
        let (r, g, b) = representativeSRGB
        return Color(red: r, green: g, blue: b)
    }

    /// Nearest palette color to a sampled sRGB triple.
    static func nearestInAddItemPalette(to rgb: (Double, Double, Double)) -> FashionColor {
        func dist2(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
            let dr = a.0 - b.0
            let dg = a.1 - b.1
            let db = a.2 - b.2
            return dr * dr + dg * dg + db * db
        }
        var best = FashionColor.addItemPalette[0]
        var bestD = dist2(rgb, best.representativeSRGB)
        for c in FashionColor.addItemPalette.dropFirst() {
            let d = dist2(rgb, c.representativeSRGB)
            if d < bestD {
                bestD = d
                best = c
            }
        }
        return best
    }
}
