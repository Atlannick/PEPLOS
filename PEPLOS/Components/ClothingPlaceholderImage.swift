//
//  ClothingPlaceholderImage.swift
//

import SwiftUI

/// Soft pastel tiles for empty categories; cycles via `pastelStyleIndex` on `ClothingCategory`.
enum ClothingPlaceholderStyle: Int, CaseIterable, Codable {
    case blue
    case mint
    case lavender
    case peach
    case pink
    case softYellow

    /// Number of distinct pastels in the rotating palette.
    static var paletteCount: Int { allCases.count }

    static func style(atPastelIndex index: Int) -> ClothingPlaceholderStyle {
        let cases = Self.allCases
        let i = ((index % cases.count) + cases.count) % cases.count
        return cases[i]
    }

    var gradient: LinearGradient {
        switch self {
        case .blue:
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.55, blue: 0.95),
                    Color(red: 0.2, green: 0.4, blue: 0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mint:
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.88, blue: 0.75),
                    Color(red: 0.35, green: 0.72, blue: 0.6),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lavender:
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.72, blue: 0.95),
                    Color(red: 0.58, green: 0.52, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .peach:
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.82, blue: 0.72),
                    Color(red: 0.95, green: 0.62, blue: 0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pink:
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.78, blue: 0.88),
                    Color(red: 0.92, green: 0.58, blue: 0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .softYellow:
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.94, blue: 0.72),
                    Color(red: 0.94, green: 0.84, blue: 0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Colourful blank tile for categories with no photo yet (shelf / cards).
struct ClothingPlaceholderImage: View {
    let style: ClothingPlaceholderStyle
    var cornerRadius: CGFloat = 20
    /// Generic garment mark — matches Home “Recently Added” category squircles when empty.
    var showsCenterSymbol: Bool = true

    private var centerSymbolSize: CGFloat {
        min(48, max(20, cornerRadius * 2.15))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.gradient)
            if showsCenterSymbol {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: centerSymbolSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
    }
}
