//
//  AppTheme.swift
//  PEPLOS
//

import SwiftUI

enum AppTheme {
    /// Matches mockup light gray (#F8F9FB–style).
    static let background = Color(red: 248 / 255, green: 249 / 255, blue: 251 / 255)
    static let cardBackground = Color.white
    static let accent = Color(red: 0.10, green: 0.36, blue: 1.0)
    static let accentSecondary = Color(red: 0.24, green: 0.35, blue: 1.0)
    static let subtitleGray = Color(red: 0.55, green: 0.56, blue: 0.58)
    static let chipInactive = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let searchButtonBorder = Color(red: 0.88, green: 0.89, blue: 0.91)

    static let outfitPink = Color(red: 0.95, green: 0.35, blue: 0.45)

    /// Tab screen titles (Closet, Stylist, Outfits) — plum tones, kept separate from Home’s time-of-day greeting gradients.
    static let screenHeaderTitleGradientColors: [Color] = [
        Color(red: 0.38, green: 0.24, blue: 0.48),
        Color(red: 0.56, green: 0.40, blue: 0.58),
    ]

    static var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.08), 16, 0, 6)
    }

    static var subtleShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.06), 10, 0, 4)
    }
}

extension View {
    func pepCardShadow() -> some View {
        shadow(
            color: AppTheme.cardShadow.color,
            radius: AppTheme.cardShadow.radius,
            x: AppTheme.cardShadow.x,
            y: AppTheme.cardShadow.y
        )
    }

    func pepSubtleShadow() -> some View {
        shadow(
            color: AppTheme.subtleShadow.color,
            radius: AppTheme.subtleShadow.radius,
            x: AppTheme.subtleShadow.x,
            y: AppTheme.subtleShadow.y
        )
    }
}
